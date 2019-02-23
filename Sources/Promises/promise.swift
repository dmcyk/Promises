//
//  promise.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

public struct Promise<T, Failure: Error> {

  public typealias ResolverType = Resolver<T, Failure>

  let resolver: ResolverType
  let queue: DispatchQueue?

  init(queue: DispatchQueue?, recover: Bool = false, _ body: @escaping (ResolverType) -> Void) {
    self.resolver = ResolverType()
    self.queue = queue

    body(self.resolver)
  }

  public init(_ value: T, on queue: DispatchQueue? = nil, bindQueue: Bool = true) {
    self.resolver = ResolverType(.success(value))
    self.queue = queue
  }

  public init(error: Failure, on queue: DispatchQueue? = nil, bindQueue: Bool = true) {
    self.resolver = ResolverType(.failure(error))
    self.queue = queue
  }

  public func bind(to queue: DispatchQueue) -> Promise {
    return Promise(queue: queue) {
      $0.pipe(to: self.resolver)
    }
  }

  public func onSuccess(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise {
    let q = on ?? queue

    return Promise(queue: queue) { r in
      self.resolver.inspect { result in
        switch result {
        case .success(let value):
          q.tryAsync {
             body(value)
             r.fulfill(value)
          }
        case .failure(let error):
          r.reject(error)
        }
      }
    }
  }

  @discardableResult
  public func `catch`(on: DispatchQueue? = nil, _ body: @escaping (Failure) -> Void) -> Promise {
    let q = on ?? queue

    return Promise(queue: queue) { r in
      self.resolver.inspect { result in
        switch result {
        case .success(let value):
          r.fulfill(value)
        case .failure(let error):
          q.tryAsync {
            body(error)
            r.cancel()
          }
        }
      }
    }
  }

  @discardableResult
  public func done(on: DispatchQueue? = nil, _ body: @escaping (T) -> Void) -> Promise<Void, Failure> {
    let q = on ?? queue

    return Promise<Void, Failure>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            body(value)
            r.fulfill(())
          }
        case .failure(let err):
          r.reject(err)
        }
      }
    }
  }

  public func then<E>(on: DispatchQueue? = nil,_ body: @escaping (T) -> Promise<E, Failure>) -> Promise<E, Failure> {
    let q = on ?? queue

    return Promise<E, Failure>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            let new = body(value)
            r.pipe(to: new.resolver)
          }
        case .failure(let err):
          r.reject(err)
        }
      }
    }
  }

  public func compactMap<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) -> E?) -> Promise<E, CompactMapError<Failure>> {
    let q = on ?? queue

    return Promise<E, CompactMapError<Failure>>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            guard let new = transform(value) else {
              r.reject(CompactMapError<Failure>.err(value, E.self))
              return
            }
            r.fulfill(new)
          }
        case .failure(let err):
          r.reject(.other(err))
        }
      }
    }
  }

  public func map<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) -> Result<E, Failure>) -> Promise<E, Failure> {
    let q = on ?? queue

    return Promise<E, Failure>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            let new = transform(value)
            r.resolve(new)
          }
        case .failure(let err):
          r.reject(err)
        }
      }
    }
  }

  public func asVoid() -> Promise<Void, Failure> {
      return map { _ in .success(()) }
  }

  public func asAny() -> Promise<Any, Failure> {
    return map { .success($0) }
  }

  public func recover(_ body: @escaping (Failure) -> Promise) -> Promise {
    let q = queue

    return Promise(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let val):
          r.fulfill(val)
        case .failure(let error):
          q.tryAsync {
            let new = body(error)
            r.pipe(to: new.resolver)
          }
        }
      }
    }
  }
}

extension Promise {

  public init(on queue: DispatchQueue? = nil, bindQueue: Bool = true, _ call: @escaping (ResolverType) -> Void) {
    self.resolver = ResolverType()
    self.queue = bindQueue ? queue : nil

    let resolver = self.resolver
    queue.tryAsync {
      call(resolver)
    }
  }
}
extension Promise where Failure == AnyError {

  public init(on queue: DispatchQueue? = nil, bindQueue: Bool = true, catching call: @escaping (ResolverType) throws -> Void) {
    self.init(on: queue, bindQueue: bindQueue) {
      do {
        try call($0)
      } catch {
        $0.reject(AnyError(error))
      }
    }
  }

  public func then<E>(on: DispatchQueue? = nil, catching body: @escaping (T) throws -> Promise<E, AnyError>) -> Promise<E, AnyError> {
    let q = on ?? queue

    return Promise<E, Failure>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            do {
              let new = try body(value)
              r.pipe(to: new.resolver)
            } catch {
              r.reject(AnyError(error))
            }
          }
        case .failure(let err):
          r.reject(err)
        }
      }
    }
  }

  public func map<E>(on: DispatchQueue? = nil, _ transform: @escaping (T) throws -> E) -> Promise<E, AnyError> {
    let q = on ?? queue

    return Promise<E, Failure>(queue: queue) { r in
      self.resolver.inspect {
        switch $0 {
        case .success(let value):
          q.tryAsync {
            do {
              let new = try transform(value)
              r.fulfill(new)
            } catch {
              r.reject(AnyError(error))
            }
          }
        case .failure(let err):
          r.reject(err)
        }
      }
    }
  }
}

extension Optional where Wrapped == DispatchQueue {

  func tryAsync(_ call: @escaping () -> Void) {
    guard let queue = self else {
      call()
      return
    }

    queue.async(execute: call)
  }
}
