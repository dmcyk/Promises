//
//  Resolver.swift
//  DNISonicKit-iOS
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2018 Discovery. All rights reserved.
//

import Foundation
import Atomic

private typealias Handler<T> = (Result<T>) -> Void
private enum Sealant<T> {

    case sealed([Handler<T>])
    case resolved(Result<T>)
    case cancelled
}

private typealias AtomicSeal<T> = Atomic<Sealant<T>, UnfairLock>
private enum Store<T> {

    case value(Result<T>)
    case seal(AtomicSeal<T>)
}

public final class Resolver<T> {

    private let value: Store<T>

    init(_ value: T? = nil) {
        let store: Store<T>
        if let value = value {
            store = .value(.success(value))
        } else {
            store = .seal(Atomic(.sealed([])))
        }

        self.value = store
    }

    func resolve(_ rawValue: Result<T>?) {
        guard case .seal(let atomic) = self.value else { return }

        var handlers: [Handler<T>]?

        guard let value: Result<T> = atomic.withWriteLock({
            guard case .sealed(let _handlers) = $0 else {
                return nil // already resolved
            }

            guard let _value = rawValue else {
                $0 = .cancelled
                return nil
            }

            handlers = _handlers
            $0 = .resolved(_value)
            return _value
        }) else { return }

        handlers?.forEach { $0(value) }
    }

    func pipe(to other: Resolver<T>) {
        other.inspect { val in
            self.resolve(val)
        }
    }

    func inspect(_ call: @escaping (Result<T>) -> Void) {
        let atomic: AtomicSeal<T>
        switch value {
        case .seal(let _atomic):
            atomic = _atomic
        case .value(let result):
            call(result)
            return
        }

        guard let result = atomic.withWriteLock({ val -> Result<T>? in
            switch val {
            case .sealed(var handlers):
                handlers.append(call)
                val = .sealed(handlers)
                return nil
            case .resolved(let _result):
                return _result
            case .cancelled: return nil
            }
        }) else { return }

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
