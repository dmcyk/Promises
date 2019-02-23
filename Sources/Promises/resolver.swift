//
//  resolver.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

typealias Handler<T, Failure: Error> = (Result<T, Failure>) -> Void
enum Sealant<T, Failure: Error> {

    case sealed([Handler<T, Failure>])
    case resolved(Result<T, Failure>)
    case cancelled
}

typealias AtomicSeal<T, Failure: Error> = Atomic<Sealant<T, Failure>>
enum Store<T, Failure: Error> {

    case value(Result<T, Failure>)
    case seal(AtomicSeal<T, Failure>)
}

public final class Resolver<T, Failure: Error> {

    let value: Store<T, Failure>

    init(_ value: Result<T, Failure>? = nil) {
      if let value = value {
        self.value = .value(value)
      } else {
        self.value = .seal(Atomic(.sealed([])))
      }
    }

    public func resolve(_ rawValue: Result<T, Failure>?) {
        guard case .seal(let atomic) = self.value else { return }

        var handlers: [Handler<T, Failure>]?

        guard let value: Result<T, Failure> = atomic.withWriteLock({
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

    func pipe(to other: Resolver<T, Failure>) {
        other.inspect { val in
            self.resolve(val)
        }
    }

    func inspect(_ call: @escaping (Result<T, Failure>) -> Void) {
        let atomic: AtomicSeal<T, Failure>
        switch value {
        case .seal(let _atomic):
            atomic = _atomic
        case .value(let result):
            call(result)
            return
        }

        guard let result = atomic.withWriteLock({ val -> Result<T, Failure>? in
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

    public func reject(_ error: Failure) {
        resolve(.failure(error))
    }
}
