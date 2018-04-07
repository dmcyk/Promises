//
//  Utils.swift
//  RequestPromises
//
//  Created by damian.malarczyk on 31/03/2018.
//

import Foundation

public enum PromiseError: Error {

    case chainBroken
    case compactMap(Any, Any.Type)
}

public enum Result<T> {

    case success(T)
    case error(Error)
}
