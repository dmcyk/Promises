//
//  Resolver.swift
//  DNISonicKit-iOS
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2018 Discovery. All rights reserved.
//

import Foundation
import Atomic

enum Sealant<T> {

    case sealed([Handler<T>])
    case resolved(Result<T>)
    case cancelled
}

final class Handler<T> {

    let body: (Result<T>) -> Void

    init(_ body: @escaping (Result<T>) -> Void) {
        self.body = body
    }
}

public final class Resolver<T> {

    private let value: Atomic<Sealant<T>, UnfairLock> = Atomic(.sealed([]))

    func resolve(_ value: Result<T>?) {
        guard let value = value else {
            self.value.withWriteLock { _ in
                return .cancelled
            }
            return
        }

        var handlers: [Handler<T>] = []
        self.value.withWriteLock {
            guard case .sealed(let _handlers) = $0 else {
                return nil // already resolved
            }

            handlers = _handlers
            return .resolved(value)
        }

        handlers.forEach { $0.body(value) }
    }

    func pipe(to other: Resolver<T>) {
        other.inspect { val in
            self.resolve(val)
        }
    }

    func inspect(_ call: @escaping (Result<T>) -> Void) {
        var preResult: Result<T>?
        value.withWriteLock {
            switch $0 {
            case .sealed(let handlers):
                let newHandler = Handler() {
                    call($0)
                }
                return .sealed(handlers + [newHandler])
            case .resolved(let _result):
                preResult = _result
                return nil
            case .cancelled:
                return nil
            }
        }

        guard let result = preResult else { return }

        call(result)
    }

    public func cancel() {
        resolve(nil)
    }

    public func fulfill(_ newValue: T) {
        resolve(.success(newValue))
    }

    public func reject(_ error: Error) {
        resolve(.error(error))
    }
}
