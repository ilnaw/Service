//
//  ServiceError.swift
//  LefullService
//
//  Created by captainteemo on 2018/11/27.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation

public enum ServiceError: LocalizedError {
	case invalidPath
	case unknownOperation
	case invalidInput
	case invalidJSON
	case objectNotFound
	case invalidLogin(message: String)
	case invalidApartment(message: String)
	case serverError(message: String)
	
	case invalidDeviceType(message: String)
	case shouldJumpToActivation(message: String)
	case invalidAuthentication(message: String)
	
	case plainMessage(message: String)
	
	public var errorDescription: String? {
		switch self {
		case .invalidPath: return "invalidPath"
		case .unknownOperation: return "unknownOperation"
		case .invalidInput: return "invalidInput"
		case .invalidJSON: return "invalidJSON"
		case .objectNotFound: return "objectNotFound"
		case .invalidLogin(message: let message): return message
		case .invalidApartment(message: let message): return message
		case .serverError(message: let message): return message
		case .invalidDeviceType(message: let message): return message
		case .shouldJumpToActivation(message: let message): return message
		case .invalidAuthentication(message: let message): return message
		case .plainMessage(message: let message): return message
		}
	}
}

