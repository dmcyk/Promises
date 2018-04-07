//
//  MutexLock.swift
//  TestAtomicTests
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2018 damian.malarczyk. All rights reserved.
//

import Foundation

private func acquire(lock: UnsafeMutablePointer<pthread_mutex_t>) -> UnsafeMutablePointer<pthread_mutex_t>? {
    let acquired: Int32 = pthread_mutex_lock(lock)
    assert(acquired != EINVAL, "passing uninitialized lock")

    if acquired == EDEADLK { // trying to acquire lock on already locked thread, so there's no need to unlock
        return nil
    }
    return lock
}

private func unlock(lock: UnsafeMutablePointer<pthread_mutex_t>?) {
    if let lock = lock {
        pthread_mutex_unlock(lock)
    }
}

final public class MutexLock: MututalLock {

    public typealias LockType = pthread_mutex_t
    private var lock: pthread_mutex_t

    public init() {
        self.lock = pthread_mutex_t()
        pthread_mutex_init(&self.lock, nil)
    }

    deinit {
        pthread_mutex_destroy(&self.lock)
    }

    func withAnyLock<T>(_ call: () -> T) -> T {
        let lock = acquire(lock: &self.lock)
        let val = call()
        unlock(lock: lock)
        return val
    }
}
