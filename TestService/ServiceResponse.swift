//
//  ServerResponse.swift
//  LefullService
//
//  Created by captainteemo on 2018/11/30.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation
import SwiftyJSON

public struct ServiceResponse<T: DataConvertible> {
	public let status: Int
	public let message: String
	public let value: T
	
	init(data: Data) throws {
		let raw = try JSON(data: data)
		try self.init(raw: raw)
	}
	
	init(raw: JSON) throws {
		let defaultMessage = "服务器正在开小差，请稍后再试"
		
		var baseURLOption: BaseURLOption = .version2
		if raw["code"].stringValue.isEmpty {
			baseURLOption = .version1
		}
		
		switch baseURLOption {
		case .version1, .custom(_):
			var message = raw["message"].stringValue
			if message.isEmpty { message = defaultMessage }
			self.message = message
			
			let status = raw["status"].intValue
			self.status = status
			
			if status == 1001 {
				throw ServiceError.invalidLogin(message: message)
			}
			if status == 1002 {
				throw ServiceError.shouldJumpToActivation(message: message)
			}
			if status == 1003 {
				throw ServiceError.invalidAuthentication(message: message)
			}
			if status == 1004 {
				throw ServiceError.invalidDeviceType(message: message)
			}
			if status == 1005 {
				throw ServiceError.invalidApartment(message: message)
			}
			if status != 1 {
				throw ServiceError.serverError(message: message)
			}
		case .version2, .version3:
			var message = raw["msg"].stringValue
			if message.isEmpty { message = defaultMessage }
			self.message = message
			
			let code = raw["code"].intValue
			self.status = code
			
			if code == 501 || code == 404{
				throw ServiceError.invalidLogin(message: message)
			}
			if code != 200 {
				throw ServiceError.serverError(message: message)
			}
		}
		
		var data: Data
		if let d = try? raw["data"].rawData() {
			data = d
		} else {
			guard let d = raw["data"].rawString(.utf8, options: .prettyPrinted)?.data(using: .utf8) else {
				throw ServiceError.invalidJSON
			}
			data = d
		}
		self.value = try T.fromData(data)
	}
}

extension ServiceResponse: DataConvertible {
	public static func fromData(_ input: Data) throws -> ServiceResponse<T> {
		return try ServiceResponse<T>(data: input)
	}
	
	public func toData() throws -> Data {
		return try self.value.toData()
	}
}
