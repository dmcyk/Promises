//
//  promise_any_err.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

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
