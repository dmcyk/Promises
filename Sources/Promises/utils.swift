//
//  utils.swift
//  Promise
//
//  Created by damian.malarczyk on 30/03/2018.
//  Copyright © 2019 dmcyk. All rights reserved.
//

import Foundation

public enum CompactMapError<Failure: Error>: Error {

  case other(Failure)
  case err(Any, Any.Type)
}
