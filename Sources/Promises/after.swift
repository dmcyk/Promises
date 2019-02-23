//
//  after.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

public func after<Failure>(_ delay: DispatchTimeInterval) -> Promise<Void, Failure> {
  return Promise<Void, Failure>() { resolver in
    DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + delay) {
      resolver.fulfill(())
    }
  }
}

public func attempt<T, Failure>(
  times maximumRetryCount: Int = 3,
  delayBeforeRetry: DispatchTimeInterval = .seconds(2),
  _ body: @autoclosure @escaping () -> Promise<T, Failure>
) -> Promise<T, Failure> {
  var attempts = 0
  func attempt() -> Promise<T, Failure> {
    attempts += 1
    return body().recover { error -> Promise<T, Failure> in
      guard attempts < maximumRetryCount else { return Promise(error: error) }
      return after(delayBeforeRetry)
        .then { _ in
          attempt()
      }
    }
  }
  return attempt()
}

public func firstly<T, Failure>(_ block: () -> Promise<T, Failure>) -> Promise<T, Failure> {
  return block()
}

public func when<T, Failure>(fulfilled: [Promise<T, Failure>]) -> Promise<Void, Failure> {
  var other = fulfilled

  guard var current = other.popLast() else {
    return Promise(())
  }

  return Promise<Void, Failure> { resolver in
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
