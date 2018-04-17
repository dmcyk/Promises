//
//  Promise.swift
//  DNISonicKit-iOS
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2018 Discovery. All rights reserved.
//

import Foundation

public struct Promise<T> {

    private struct ActionCtx {

        let resolver: Resolver<T>
        let isRecovery: Bool

        init(_ resolver: Resolver<T>, isRecovery: Bool) {
            self.resolver = resolver
            self.isRecovery = isRecovery
        }

        func sourceResolver<E>(from src: Promise<E>) -> Resolver<E> {
            return (isRecovery ? src.recoverChain() : src).resolver
        }
    }

    private let resolver: Resolver<T>
    private let queue: DispatchQueue?
    private let action: (ActionCtx) -> Void

    public init(on queue: DispatchQueue? = nil, bindQueue: Bool = true, _ call: @escaping (Resolver<T>) throws -> Void) {
        self.resolver = Resolver<T>()
        self.queue = bindQueue ? queue : nil
        self.action = {
            do {
                try call($0.resolver)
            } catch {
                $0.resolver.reject(error)
            }
        }

        let action = self.action
        let resolver = self.resolver
        queue.tryAsync {
            action(ActionCtx(resolver, isRecovery: false))
        }
    }

    private init(queue: DispatchQueue?, recover: Bool = false, _ body: @escaping (ActionCtx) -> Void) {
        self.resolver = Resolver<T>()
        self.queue = queue
        self.action = body

        body(ActionCtx(resolver, isRecovery: recover))
    }

    public init(_ value: T, on queue: DispatchQueue? = nil, bindQueue: Bool = true) {
        self.resolver = Resolver<T>(value)
        self.queue = queue
        self.action = { _ in }
    }

    public func bind(to queue: DispatchQueue) -> Promise<T> {
        return Promise(queue: queue) {
            $0.resolver.pipe(to: $0.sourceResolver(from: self))
        }
    }

    public func onSuccess(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise {
        let q = on ?? queue

        return Promise(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect { result in
                switch result {
                case .success(let value):
                    q.tryAsync {
                        body(value)
                        ctx.resolver.fulfill(value)
                    }
                case .error(let error):
                    ctx.resolver.reject(error)
                }
            }
        }
    }

    @discardableResult
    public func `catch`(on: DispatchQueue? = nil, _ body: @escaping (Error) -> Void) -> Promise {
        let q = on ?? queue

        return Promise(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect { result in
                switch result {
                case .success(let value):
                    ctx.resolver.fulfill(value)
                case .error(let error):
                    q.tryAsync {
                        body(error)
                        ctx.resolver.cancel()
                    }
                }
            }
        }
    }

    @discardableResult
    public func done(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise<Void> {
        let q = on ?? queue

        return Promise<Void>(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        body(value)
                        ctx.resolver.fulfill(())
                    }
                case .error(let err):
                    ctx.resolver.reject(err)
                }
            }
        }
    }

    public func then<E>(on: DispatchQueue? = nil,_ body: @escaping (T) throws -> Promise<E>) -> Promise<E> {
        let q = on ?? queue

        return Promise<E>(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        do {
                            let new = try body(value)
                            ctx.resolver.pipe(to: new.resolver)
                        } catch {
                            ctx.resolver.reject(error)
                        }
                    }
                case .error(let err):
                    ctx.resolver.reject(err)
                }
            }
        }
    }

    public func compactMap<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) throws -> E?) -> Promise<E> {
        let q = on ?? queue

        return Promise<E>(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        do {
                            guard let new = try transform(value) else {
                                ctx.resolver.reject(PromiseError.compactMap(value, E.self))
                                return
                            }
                            ctx.resolver.fulfill(new)
                        } catch {
                            ctx.resolver.reject(error)
                        }
                    }
                case .error(let err):
                    ctx.resolver.reject(err)
                }
            }
        }
    }

    public func map<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) throws -> E) -> Promise<E> {
        return compactMap(transform)
    }

    public func asVoid() -> Promise<Void> {
        return map { _ in }
    }

    public func asAny() -> Promise<Any> {
        return map { $0 }
    }

    public func recover(_ body: @escaping (Error) throws -> Promise<T>) -> Promise<T> {
        let q = queue

        return Promise<T>(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect {
                switch $0 {
                case .success(let val):
                    ctx.resolver.fulfill(val)
                case .error(let error):
                    q.tryAsync {
                        do {
                            let new = try body(error)
                            ctx.resolver.pipe(to: new.resolver)
                        } catch {
                            ctx.resolver.reject(error)
                        }
                    }
                }
            }
        }
    }

    public func recoverChain(_ callback: ((Error) -> Void)? = nil) -> Promise<T> {
        let call = action
        let q = queue

        return Promise<T>(queue: queue) { ctx in
            self.resolver.inspect {
                switch $0 {
                case .success(let val):
                    ctx.resolver.fulfill(val)
                case .error(let err):
                    q.tryAsync {
                        callback?(err)
                    }

                    let new = Promise(queue: q, recover: true, call)
                    ctx.resolver.pipe(to: new.resolver)
                }
            }
        }
    }

    private func performAttempt(callback: @escaping (Error) -> Bool, callbackQueue: DispatchQueue?, times: Int, delay: DispatchTimeInterval, resolver: Resolver<T>) {
        after(delay)
            .done {
                self.recoverChain()
                    .resolver
                    .inspect {
                        switch $0 {
                        case .success(let value):
                            resolver.fulfill(value)
                        case .error(let error):
                            guard times > 0 else {
                                resolver.reject(error)
                                return
                            }

                            callbackQueue.tryAsync {
                                guard callback(error) else {
                                    resolver.reject(error)
                                    return
                                }

                                self.performAttempt(callback: callback, callbackQueue: callbackQueue, times: times - 1, delay: delay, resolver: resolver)
                            }
                        }
                    }
            }
    }

    public func attempt(on: DispatchQueue? = nil, times: Int, delayBeforeRetry: DispatchTimeInterval = .seconds(2), _ callback: @escaping (Error) -> Bool) -> Promise {
        guard times > 0 else { return self }

        let q = on ?? queue

        return Promise(queue: queue) { ctx in
            ctx.sourceResolver(from: self).inspect {
                switch $0 {
                case .success(let val):
                    ctx.resolver.fulfill(val)
                case .error(let error):
                    q.tryAsync {
                        guard callback(error) else {
                            ctx.resolver.reject(error)
                            return
                        }
                        self.performAttempt(callback: callback, callbackQueue: q, times: times, delay: delayBeforeRetry, resolver: ctx.resolver)
                    }
                }
            }
        }
    }
}

private extension Optional where Wrapped == DispatchQueue {

    func tryAsync(_ call: @escaping () -> Void) {
        guard let queue = self else {
            call()
            return
        }

        queue.async(execute: call)
    }
}
