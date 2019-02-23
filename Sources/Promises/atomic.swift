//
//  atomic.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

final class UnfairLock {

  private let _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)

  init() {
    self._lock.pointee = os_unfair_lock()
  }

  deinit {
    self._lock.deinitialize(count: 1)
    self._lock.deallocate()
  }

  func lock() {
    os_unfair_lock_lock(self._lock)
  }

  func unlock() {
    os_unfair_lock_unlock(self._lock)
  }

  // https://bugs.swift.org/browse/SR-9772
  func withLock<T, Context>(_ context: Context, _ call: (Context) -> T) -> T {
    self.lock(); defer { self.unlock() }
    return call(context)
  }
}

final class Atomic<T> {

  private let lock = UnfairLock()
  private var _value: T

  init(_ val: T) {
    self._value = val
  }

  func read() -> T {
    return self.lock.withLock(self) {
      $0._value
    }
  }

  func write(_ value: T) {
    return self.lock.withLock(self) {
      $0._value = value
    }
  }

  func withWriteLock<E>(_ call: (inout T) -> E) -> E {
    return self.lock.withLock(self) {
      return call(&$0._value)
    }
  }

  func withReadLock<E>(_ call: (T) -> E) -> E {
    return self.lock.withLock(self) {
      return call($0._value)
    }
  }
}
