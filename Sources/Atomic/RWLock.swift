//
//  RWLock.swift
//  TestAtomicTests
//
//  Created by damian.malarczyk on 03/12/2017.
//  Copyright © 2017 damian.malarczyk. All rights reserved.
//

import Foundation

private func acquire(lock: UnsafeMutablePointer<pthread_rwlock_t>, type: LockKind) -> UnsafeMutablePointer<pthread_rwlock_t>? {
    let acquired: Int32 = {
        switch type {
        case .read:
            var attr: Int32 = pthread_rwlock_rdlock(lock)
            while attr == EAGAIN {
                usleep(1000 * 100) // sleep for 100 milliseconds
                attr = pthread_rwlock_rdlock(lock)
            }

            return attr
        case .write: return pthread_rwlock_wrlock(lock)
        }
    }()

    assert(acquired != EINVAL, "passing uninitialized lock")

    if acquired == EDEADLK { // trying to acquire lock on already locked thread, so there's no need to unlock
        return nil
    }
    return lock
}

private func unlock(lock: UnsafeMutablePointer<pthread_rwlock_t>?) {
    if let lock = lock {
        pthread_rwlock_unlock(lock)
    }
}

final public class ReadWriteLock: Lock {

    public typealias LockType = pthread_rwlock_t

    private var lock: pthread_rwlock_t

    public init() {
        self.lock = pthread_rwlock_t()
        pthread_rwlock_init(&self.lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&self.lock)
    }

    func withLock<T>(of kind: LockKind, _ call: () -> T) -> T {
        switch kind {
        case .read:
            return withReadLock(call)
        case .write:
            return withWriteLock(call)
        }
    }


    public func withReadLock<T>(_ call: () -> T) -> T {
        let lock = acquire(lock: &self.lock, type: .read)
        let val = call()
        unlock(lock: lock)
        return val
    }

    public func withWriteLock<T>(_ call: () -> T) -> T {
        let lock = acquire(lock: &self.lock, type: .write)
        let val = call()
        unlock(lock: lock)
        return val
    }
}
