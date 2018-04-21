//
//  UnfairLock.swift
//  TestAtomic
//
//  Created by Damian Malarczyk on 04/04/2018.
//

import Foundation

@available(macOS 10.12, iOS 10.0, *)
final private class _UnfairLock: MututalLock {

    typealias LockType = os_unfair_lock

    var lock = os_unfair_lock()

    public func withAnyLock<T>(_ call: () -> T) -> T {
        os_unfair_lock_lock(&lock)
        let val = call()
        os_unfair_lock_unlock(&lock)
        return val
    }
}

final public class UnfairLock: Lock {

    public typealias LockType = os_unfair_lock_s

    private var lock: Any

    public init() {
        if #available(macOS 10.12, iOS 10.0, *) {
            lock = _UnfairLock()
        } else {
            lock = ReadWriteLock()
        }
    }

    public func withReadLock<T>(_ call: () -> T) -> T {
        if #available(macOS 10.12, iOS 10.0, *) {
            return (lock as! _UnfairLock).withAnyLock(call)
        } else {
            return (lock as! ReadWriteLock).withReadLock(call)
        }
    }

    public func withWriteLock<T>(_ call: () -> T) -> T {
        if #available(macOS 10.12, iOS 10.0, *) {
            return (lock as! _UnfairLock).withAnyLock(call)
        } else {
            return (lock as! ReadWriteLock).withWriteLock(call)
        }
    }
}
