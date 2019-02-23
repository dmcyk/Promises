//
//  any_error.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

/// Swift 5 compatibility where `Error` protocol conforms to itself
public struct AnyError: LocalizedError {

  public let error: Error

  private var localized: LocalizedError? { return self.error as? LocalizedError }

  public var _domain: String { return self.error._domain }
  public var _code: Int { return self.error._code }
  public var _userInfo: AnyObject? { return self.error._userInfo }

  public var errorDescription: String? { return self.localized?.errorDescription }
  public var failureReason: String? { return self.localized?.failureReason }
  public var recoverySuggestion: String? { return self.localized?.recoverySuggestion }
  public var helpAnchor: String? { return self.localized?.helpAnchor }

  public init(_ error: Error) {
    self.error = (error as? AnyError)?.error ?? error
  }
}

