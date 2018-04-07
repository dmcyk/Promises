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

    public var value: T {
        get {
            return lock.withReadLock {
                _value
            }
        }
        set {
            lock.withWriteLock {
                _value = newValue
            }
        }
    }

    public init(_ value: T) {
        _value = value
    }

    public func withWriteLock(_ call: (T) -> T?) {
        lock.withWriteLock {
            guard let value = call(_value) else {
                return
            }

            _value = value
        }
    }

    public func withReadLock<E>(_ call: (T) -> E) -> E {
        return lock.withReadLock {
            return call(_value)
        }
    }
}
