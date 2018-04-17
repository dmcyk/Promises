//
//  Promise.swift
//  DNISonicKit-iOS
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2018 Discovery. All rights reserved.
//

import Foundation

public struct Promise<T> {

    let resolver: Resolver<T>
    let queue: DispatchQueue?

    public init(on queue: DispatchQueue? = nil, bindQueue: Bool = true, _ call: @escaping (Resolver<T>) throws -> Void) {
        self.resolver = Resolver<T>()
        self.queue = bindQueue ? queue : nil

        let resolver = self.resolver
        queue.tryAsync {
            do {
                try call(resolver)
            } catch {
                resolver.reject(error)
            }
        }
    }

    init(queue: DispatchQueue?, recover: Bool = false, _ body: @escaping (Resolver<T>) -> Void) {
        self.resolver = Resolver<T>()
        self.queue = queue

        body(self.resolver)
    }

    public init(_ value: T, on queue: DispatchQueue? = nil, bindQueue: Bool = true) {
        self.resolver = Resolver<T>(value)
        self.queue = queue
    }

    public func bind(to queue: DispatchQueue) -> Promise<T> {
        return Promise(queue: queue) {
            $0.pipe(to: self.resolver)
        }
    }

    public func onSuccess(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise {
        let q = on ?? queue

        return Promise(queue: queue) { r in
            self.resolver.inspect { result in
                switch result {
                case .success(let value):
                    q.tryAsync {
                        body(value)
                        r.fulfill(value)
                    }
                case .error(let error):
                    r.reject(error)
                }
            }
        }
    }

    @discardableResult
    public func `catch`(on: DispatchQueue? = nil, _ body: @escaping (Error) -> Void) -> Promise {
        let q = on ?? queue

        return Promise(queue: queue) { r in
            self.resolver.inspect { result in
                switch result {
                case .success(let value):
                    r.fulfill(value)
                case .error(let error):
                    q.tryAsync {
                        body(error)
                        r.cancel()
                    }
                }
            }
        }
    }

    @discardableResult
    public func done(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise<Void> {
        let q = on ?? queue

        return Promise<Void>(queue: queue) { r in
            self.resolver.inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        body(value)
                        r.fulfill(())
                    }
                case .error(let err):
                    r.reject(err)
                }
            }
        }
    }

    public func then<E>(on: DispatchQueue? = nil,_ body: @escaping (T) throws -> Promise<E>) -> Promise<E> {
        let q = on ?? queue

        return Promise<E>(queue: queue) { r in
            self.resolver.inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        do {
                            let new = try body(value)
                            r.pipe(to: new.resolver)
                        } catch {
                            r.reject(error)
                        }
                    }
                case .error(let err):
                    r.reject(err)
                }
            }
        }
    }

    public func compactMap<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) throws -> E?) -> Promise<E> {
        let q = on ?? queue

        return Promise<E>(queue: queue) { r in
            self.resolver.inspect {
                switch $0 {
                case .success(let value):
                    q.tryAsync {
                        do {
                            guard let new = try transform(value) else {
                                r.reject(PromiseError.compactMap(value, E.self))
                                return
                            }
                            r.fulfill(new)
                        } catch {
                            r.reject(error)
                        }
                    }
                case .error(let err):
                    r.reject(err)
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

        return Promise<T>(queue: queue) { r in
            self.resolver.inspect {
                switch $0 {
                case .success(let val):
                    r.fulfill(val)
                case .error(let error):
                    q.tryAsync {
                        do {
                            let new = try body(error)
                            r.pipe(to: new.resolver)
                        } catch {
                            r.reject(error)
                        }
                    }
                }
            }
        }
    }
}

extension Optional where Wrapped == DispatchQueue {

    func tryAsync(_ call: @escaping () -> Void) {
        guard let queue = self else {
            call()
            return
        }

        queue.async(execute: call)
    }
}
