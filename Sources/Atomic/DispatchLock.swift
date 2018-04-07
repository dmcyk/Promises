//
//  DispatchLock.swift
//  TestAtomic
//
//  Created by Damian Malarczyk on 04/04/2018.
//

import Foundation

final public class DispatchLock: MututalLock {

    public typealias LockType = DispatchQueue
    private let queue = DispatchQueue(label: "com.atomic.lock_queue")

    public init() { }

    public func withAnyLock<T>(_ call: () -> T) -> T {
        return queue.sync {
            return call()
        }
    }
}
