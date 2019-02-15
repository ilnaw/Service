//
//  ServiceMiddlewares.swift
//  TestProject
//
//  Created by wanli on 2019/1/30.
//  Copyright © 2019 wanli. All rights reserved.
//

import Foundation

public protocol ServiceMiddleware {
    func didRecieveError(error:ServiceError)
    func mapError(error:Error) -> ServiceError
    func shouldAddHeaders(path:String) -> [String:String]
    func localDataComparable(remoteData: Data, localData: Data) -> Bool
}

public extension ServiceMiddleware {
    func didRecieveError(error:ServiceError){}
    func shouldAddHeaders(path:String) -> [String:String] { return [:] }
    func mapError(error:Error) -> ServiceError {
        var finalError : ServiceError
        if let e = error as? ServiceError {
            finalError = e
        }
        else
        {
            finalError = ServiceError.plainMessage(message: error.localizedDescription)
        }
        return finalError
    }
    func localDataComparable(remoteData: Data, localData: Data) -> Bool {
        return remoteData.md5() == localData.md5()
    }
}
