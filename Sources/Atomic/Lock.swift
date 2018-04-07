//
//  AtomicBox.swift
//  TestAtomic
//
//  Created by Damian Malarczyk on 04/04/2018.
//

import Foundation

enum LockKind {

    case read
    case write
}

public protocol Lock {

    associatedtype LockType

    init()
    func withReadLock<T>(_ call: () -> T) -> T
    func withWriteLock<T>(_ call: () -> T) -> T
}

protocol MututalLock: Lock {

    func withAnyLock<T>(_ call: () -> T) -> T
}

extension MututalLock {

    public func withReadLock<T>(_ call: () -> T) -> T {
        return withAnyLock(call)
    }

    public func withWriteLock<T>(_ call: () -> T) -> T {
        return withAnyLock(call)
    }
}
