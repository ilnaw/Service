//
//  ServiceMiddlewarePlugin.swift
//  TestProject
//
//  Created by wanli on 2019/1/30.
//  Copyright © 2019 wanli. All rights reserved.
//

import Foundation
import Moya
import Result

class ServiceMiddlewarePlugin: PluginType {
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var request = request
        ServiceConfiguration.middlewares.reduce([String:String]()) { (header, middleware) -> [String:String] in
            return middleware.shouldAddHeaders(path: target.path).merging(header, uniquingKeysWith: { (oldKey, newKey) -> String in
                return newKey
            })
        }.forEach({ (key, value) in
            request.addValue(value, forHTTPHeaderField: key)
        })
        
        return request
    }
    
    func willSend(_ request: RequestType, target: TargetType) {
        if ServiceConfiguration.isLogEnabled {
            print("\(String(describing: request.request?.url?.absoluteString))-----------\(target.task)")
        }
    }
    
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        if ServiceConfiguration.isLogEnabled {
            do{
                switch result {
                case .success(let response):
                    print(try response.mapString())
                case .failure(let error):
                   throw error
                }
            }
            catch{}
        }
    }
}
