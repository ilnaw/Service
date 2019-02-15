//
//  FactoryProvider.swift
//  TestProject
//
//  Created by wanli on 2019/1/29.
//  Copyright © 2019 wanli. All rights reserved.
//

import Foundation
import Moya
import Result
import SwiftyJSON

public struct FactoryProvider<T: DataConvertible> {
    
    @discardableResult public static func await<R:TargetType&ExtensionTargetType>(_ target: R, completion: @escaping (Result<T,ServiceError>) -> Void) -> Cancellable {
     
        var cachaData : Data?
        
        let requestClosure = { (endpoint: Endpoint, done: MoyaProvider.RequestResultClosure) in
            do {
                var request = try endpoint.urlRequest()
                //设置请求时长
                request.timeoutInterval = 20
                //设置header
//                request.addValue(<#T##value: String##String#>, forHTTPHeaderField: <#T##String#>)
                //请求缓存
                if target.offline && target.method == .get {
                    if let cacheKey = request.url?.absoluteString
                        ,let data = ServiceConfiguration.entity.getCache(for: cacheKey){
                        cachaData = data
                        let response = Response(statusCode: 200, data: data)
                        do {
                            let result = try Result<T,ServiceError>(value: T.fromData(data))
                            ServiceConfiguration.defaultPlugins.first?.didReceive(Result<Response,MoyaError>(value:response), target: target)
                            completion(result)
                        }
                        catch
                        {
                            handleError(error,completion:completion)
                        }
                    }
                }
                done(.success(request))
            } catch {
                done(.failure(MoyaError.underlying(error, nil)))
            }
        }
        
        let provider = MoyaProvider<R>(requestClosure:requestClosure,plugins:ServiceConfiguration.defaultPlugins)
        return provider.request(target, completion: { (result) in
            do {
            switch result {
                case .success(let response):
                    if target.offline, let cacheKey = response.request?.url?.absoluteString{
                        ServiceConfiguration.entity.setCache(response.data, for: cacheKey)
                    }
                    let isNewData = ServiceConfiguration.middlewares.filter({
                        if let cd = cachaData {
                            return $0.localDataComparable(remoteData: response.data, localData: cd)
                        }
                        return false
                    }).isEmpty
                    
                    if isNewData {
                       completion(Result<T,ServiceError>(value: try T.fromData(response.data)))
                    }
                case .failure(_):
                    throw ServiceError.serverError(message: "网络开小差")
                }
            }
            catch{
                handleError(error, completion: completion)
            }
        })
    }
    
    static func handleError(_ error:Error, completion: @escaping (Result<T,ServiceError>) -> Void){
        let finalError = ServiceConfiguration.middlewares.reduce(error, { (previousError, middleware) -> ServiceError in
            return middleware.mapError(error: previousError)
        }) as! ServiceError
        
        ServiceConfiguration.middlewares.forEach({
            $0.didRecieveError(error: finalError)
        })
        completion(Result<T,ServiceError>(error : finalError))
    }
}
