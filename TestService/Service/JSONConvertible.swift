//
//  JSONConvertible.swift
//  LefullService
//
//  Created by captainteemo on 2018/12/4.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation
import SwiftyJSON

public protocol JSONConvertible {
	static func fromJSON(_ input: JSON) throws -> Self
	func toJSON() throws -> JSON
}

public extension JSONConvertible where Self: Codable {
	static func fromJSON(_ input: JSON) throws -> Self {
		return try SafeJSONDecoder().decode(Self.self, from: try input.rawData())
	}
	
	func toJSON() throws -> JSON {
		let data = try JSONEncoder().encode(self)
		return JSON(data)
	}
}

extension Array: JSONConvertible where Element: JSONConvertible, Element: Codable {
	public static func fromJSON(_ input: JSON) throws -> Array<Element> {
		return try input.arrayValue.compactMap { try Element.fromJSON($0) }
	}
	
	public func toJSON() throws -> JSON {
		return JSON(try self.compactMap { try $0.toJSON() })
	}
}

class SafeJSONDecoder: JSONDecoder {
	init(camelCase: Bool = false) {
		super.init()
		
		if camelCase {
			keyDecodingStrategy = .convertFromSnakeCase
		}
	}
}
