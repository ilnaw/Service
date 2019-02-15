//
//  ServiceConfiguration.swift
//  TestProject
//
//  Created by wanli on 2019/1/30.
//  Copyright © 2019 wanli. All rights reserved.
//

import Foundation
import UIKit
import Moya

public enum BaseURLOption {
    case version1
    case version2
    case version3
    case custom(String)
    
    public func value() -> String {
        switch self {
        case .version1:
            return ServiceConfiguration.entity.baseURL.version1
        case .version2:
            return ServiceConfiguration.entity.baseURL.version2
        case .version3:
            return ServiceConfiguration.entity.baseURL.version3
        case .custom(let baseURL):
            return baseURL
        }
    }
}

public struct BaseURL: Equatable {
    public let version1: String
    public let version2: String
    public let version3: String
    public let custom: String
    
    public init(
        version1: String,
        version2: String,
        version3: String = "",
        custom: String = ""
        ) {
        self.version1 = version1
        self.version2 = version2
        self.version3 = version3
        self.custom    = custom
    }
}


public struct ServiceConfiguration{
    
    public static var defaultPlugins: [PluginType] = [ServiceMiddlewarePlugin()]
    public static var middlewares : [ServiceMiddleware] = []
    public static var isLogEnabled: Bool = false
    
    static var entity : ServiceConfiguration!{
        didSet{
            if entity.cache.isEmpty {
                entity.loadCache()
            }
        }
    }
    
    var baseURL: BaseURL
    let cachePath : String
    var cache : [String: Data] = [:]
    let cacheObserver : CacheObserver
    
    let semaphore = DispatchSemaphore(value: 1)
    
    public static func create(baseURL: BaseURL, cachePath: String ,middlewares:[ServiceMiddleware]){
        entity = ServiceConfiguration(baseURL: baseURL,cachePath: cachePath)
        ServiceConfiguration.middlewares = middlewares
    }
    
    init(baseURL: BaseURL,cachePath: String) {
        self.baseURL = baseURL
        self.cachePath = cachePath
        self.cacheObserver = CacheObserver()
    }
    
    func getCache(for key: String) -> Data? {
        semaphore.wait()
        let value = self.cache[key]
        semaphore.signal()
        return value
    }
    
    mutating func setCache(_ value: Data,for key: String) {
        semaphore.wait()
        self.cache[key] = value
        semaphore.signal()
    }
    
    mutating func loadCache() {
        var cache : [String: Data] = [:]
        if let data = FileManager.default.contents(atPath: self.cachePath) ,
            let object = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String : Data] {
            cache = object
        }
        self.cache = cache
    }
    
    mutating func saveCache() {
        let data = NSKeyedArchiver.archivedData(withRootObject: self.cache)
        if FileManager.default.fileExists(atPath: self.cachePath) {
            try? FileManager.default.removeItem(atPath: self.cachePath)
        }
        
        let created = FileManager.default.createFile(atPath: self.cachePath, contents: data, attributes: nil)
        if !created {
            print("error creating cache file")
        }
    }
    
    public static func getCacheSize() -> Int64 {
        let data =  FileManager.default.contents(atPath: ServiceConfiguration.entity.cachePath)
        return Int64(data?.count ?? 0)
    }
    
    public static func clearCache() throws {
        try FileManager.default.removeItem(atPath: ServiceConfiguration.entity.cachePath)
    }
}

final class CacheObserver {
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(saveCache), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveCache), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func saveCache(){
        ServiceConfiguration.entity.saveCache()
    }
}
