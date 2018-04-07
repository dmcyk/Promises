//
//  UnfairLock.swift
//  TestAtomic
//
//  Created by Damian Malarczyk on 04/04/2018.
//

import Foundation

final public class UnfairLock: MututalLock {

    public typealias LockType = os_unfair_lock_s

    private var lock: Any

    @available(macOS 10.12, *)
    @available(iOS 10.0, *)
    private var osLock: UnsafeMutablePointer<os_unfair_lock_s> {
        return withUnsafeMutablePointer(to: &lock, { $0 })
            .withMemoryRebound(to: os_unfair_lock_s.self, capacity: 1, { $0 })
    }

    @available(macOS, obsoleted: 10.12)
    @available(iOS, obsoleted: 10.0)
    private var mutexLock: UnsafeMutablePointer<pthread_mutex_t> {
        return withUnsafeMutablePointer(to: &lock, { $0 })
            .withMemoryRebound(to: pthread_mutex_t.self, capacity: 1, { $0 })
    }

    private func withLockRebound<T, E>(to: T.Type, _ call: (UnsafeMutablePointer<T>) -> E) -> E {
        return withUnsafeMutablePointer(to: &lock, {
            return $0.withMemoryRebound(to: T.self, capacity: 1, { return call($0) })
        })
    }

    public init() {
        lock = os_unfair_lock_s()
    }

    public func withAnyLock<T>(_ call: () -> T) -> T {
        if #available(macOS 10.12, iOS 10.0, *) {
            return withLockRebound(to: os_unfair_lock_s.self) {
                os_unfair_lock_lock($0)
                let val = call()
                os_unfair_lock_unlock($0)
                return val
            }
        } else {
            return withLockRebound(to: pthread_mutex_t.self) {
                pthread_mutex_lock($0)
                let val = call()
                pthread_mutex_unlock($0)
                return val
            }
        }
    }
}
