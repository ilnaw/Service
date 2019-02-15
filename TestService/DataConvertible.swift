//
//  DataConvertible.swift
//  LefullService
//
//  Created by captainteemo on 2018/11/28.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation
import SwiftyJSON

public protocol DataConvertible {
	static var forceCamelCase: Bool { get }
	
	static func fromData(_ input: Data) throws -> Self
	func toData() throws -> Data
}

public extension DataConvertible {
	public static var forceCamelCase: Bool { return false }
}

public extension DataConvertible where Self: Codable {
	static func fromData(_ input: Data) throws -> Self {
		return try SafeJSONDecoder(camelCase: Self.forceCamelCase).decode(Self.self, from: input)
	}
	
	func toData() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}

extension String: DataConvertible {
	public static func fromData(_ input: Data) throws -> String {
		if let result = String(data: input, encoding: .utf8) {
			return result
		}
		throw ServiceError.invalidInput
	}
	
	public func toData() throws -> Data {
		if let data = self.data(using: .utf8) {
			return data
		}
		throw ServiceError.invalidInput
	}
}

extension Int: DataConvertible {
	public static func fromData(_ input: Data) throws -> Int {
		var result: UInt8 = 0
		input.copyBytes(to: &result, count: MemoryLayout<Int>.size)
		return Int(result)
	}
	
	public func toData() throws -> Data {
		var value = self
		return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
	}
}

extension JSON: DataConvertible {
	public static func fromData(_ input: Data) throws -> JSON {
		return try JSON(data: input, options: .allowFragments)
	}
	
	public func toData() throws -> Data {
		return try self.rawData()
	}
}

extension Array: DataConvertible where Element: DataConvertible, Element: Codable {
	public static func fromData(_ input: Data) throws -> Array<Element> {
		return try JSON(data: input, options: .allowFragments).arrayValue.compactMap { try Element.fromData(try $0.rawData()) }
//		return try SafeJSONDecoder(camelCase: Element.forceCamelCase).decode(Array<Element>.self, from: input)
	}
	
	public func toData() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
