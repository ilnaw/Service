//
//  TestApi.swift
//  TestProject
//
//  Created by wanli on 2019/1/29.
//  Copyright © 2019 wanli. All rights reserved.
//

import Foundation
import Moya

public protocol ExtensionTargetType {
    var offline: Bool { get }
    var showLoading: Bool { get }
}

public enum Rental{
    case CheckinList(
        page:Int,
        pageSize:Int,
        apartmentId:String,
        checkInType:Int,
        beginTime:Int?,
        endTime:Int?)
    case UnVisitOrderCount
    case OrganizationList(employeeGroupId: String)
    case EmployeeList(employeeGroupId: String)
}

extension Rental : TargetType,ExtensionTargetType{
    
    public var offline: Bool {
        switch self {
        case .OrganizationList,.EmployeeList:
            return true
        default:
            return false
        }
    }
    
    public var showLoading: Bool{
        return false
    }
    
    public var baseURL: URL {
        switch self {
        default:
            return URL(string: BaseURLOption.version1.value())!
        }
    }
    public var path: String {
        switch self {
        case .CheckinList:
            return "/tenancy/api/v1/checkin/checkInListLisa"
        case .UnVisitOrderCount:
            return "/customerorder/api/v1/applet/findCustomerOrderCountByStatus"
        case .OrganizationList:
            return "/organization/orgManage/findOrgAndChildByGroupById"
        case .EmployeeList:
            return "/organization/User/employeeListByEmployeeGroup"
        }
    }
    
    public var method: Moya.Method {
        switch self {
        default:
            return .get
        }
    }
    
    public var task: Task
    {
        switch self {
        case .CheckinList(let page,let pageSize,let apartmentId,let checkInType, _, _):
            return .requestParameters(parameters: [
                "page": page,
                "pageSize": pageSize,
                "apartmentId": apartmentId,
                "checkInType": checkInType,
                ], encoding: URLEncoding.default)
        case .UnVisitOrderCount:
            return .requestPlain
        case .OrganizationList(let employeeGroupId):
            return .requestParameters(parameters: ["employeeGroupId":employeeGroupId], encoding: URLEncoding.default)
        case .EmployeeList(let employeeGroupId):
            return .requestParameters(parameters: [
                "employeeGroupId":employeeGroupId,
                "pageNum":"1",
                "pageSize":"10000"
                ], encoding: URLEncoding.default)
        }
    }
    
    public var sampleData: Data {
        return Data()
    }
    
    public var headers: [String : String]?
    {
        return nil
    }
}
