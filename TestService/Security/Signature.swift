//
//  Signature.swift
//  LefullService
//
//  Created by captainteemo on 2018/11/26.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation
import CommonCrypto

public struct Signature {
	static private func sortedQueryString(sortedParams: [(String, Any)]) -> String {
		return sortedParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
	}
	
	public static func sign(secret: String, params: [String: Any]) -> String? {
		var paramsToSign = params
		paramsToSign["secret"] = secret
		
		let sorted = paramsToSign.sorted(by: { $0.0 > $1.0 } )
		var salt = ""
		if secret.count >= 15 {
			salt = String(secret[secret.index(secret.startIndex, offsetBy: 5)..<secret.index(secret.startIndex, offsetBy: 15)])
		}
		let resultString = salt.appending(sortedQueryString(sortedParams: sorted))
		let md5 = resultString.md5()
		return md5
	}
}

extension Data {
	public func md5() -> String {
		let length = Int(CC_MD5_DIGEST_LENGTH)
		var digest = [UInt8](repeating: 0, count: length)
		_ = self.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
			CC_MD5(body, CC_LONG(self.count), &digest)
		}
		return (0..<length).reduce("") {
			$0 + String(format: "%02x", digest[$1])
		}
	}
}

extension String {
	public func md5() -> String {
		return self.data(using: String.Encoding.utf8)?.md5() ?? ""
	}
}
