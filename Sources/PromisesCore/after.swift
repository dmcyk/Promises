//
//  after.swift
//  RequestPromises
//
//  Created by damian.malarczyk on 31/03/2018.
//

import Foundation

public func after(_ delay: DispatchTimeInterval) -> Promise<Void> {
    return Promise() { resolver in
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + delay) {
            resolver.fulfill(())
        }
    }
}

public func attempt<T>(times maximumRetryCount: Int = 3, delayBeforeRetry: DispatchTimeInterval = .seconds(2), _ body: @autoclosure @escaping () -> Promise<T>) -> Promise<T> {
    var attempts = 0
    func attempt() -> Promise<T> {
        attempts += 1
        return body().recover { error -> Promise<T> in
            guard attempts < maximumRetryCount else { throw error }
            return after(delayBeforeRetry)
                .then { _ in
                    attempt()
                }
        }
    }
    return attempt()
}

public func firstly<T>(_ block: () -> Promise<T>) -> Promise<T> {
    return block()
}

public func when<T>(fulfilled: [Promise<T>]) -> Promise<Void> {
    var other = fulfilled

    guard var current = other.popLast() else {
        return Promise(value: ())
    }

    return Promise<Void> { resolver in
        while let next = other.popLast() {
            current = current
                .then { _ in
                    return next
                }
        }

        current
            .done { _ in
                resolver.fulfill(())
            }.catch {
                resolver.reject($0)
            }
    }
}
