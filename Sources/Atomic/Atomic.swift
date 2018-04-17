//
//  Atomic.swift
//  TestAtomicTests
//
//  Created by damian.malarczyk on 03/12/2017.
//  Copyright © 2017 damian.malarczyk. All rights reserved.
//

import Foundation

public final class Atomic<T, K: Lock> {

    private let lock = K()
    private var _value: T

    public init(_ value: T) {
        _value = value
    }

    public func write(_ value: T) {
        lock.withWriteLock {
            _value = value
        }
    }

    public func read() -> T {
        return lock.withReadLock {
            return _value
        }
    }

    public func withWriteLock<E>(_ call: (inout T) -> E) -> E {
        return lock.withWriteLock {
            return call(&_value)
        }
    }

    public func withReadLock<E>(_ call: (T) -> E) -> E {
        return lock.withReadLock {
            return call(_value)
        }
    }
}
