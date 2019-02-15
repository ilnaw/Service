//
//  Keychain.swift
//  LefullService
//
//  Created by captainteemo on 2018/11/23.
//  Copyright © 2018 captainteemo. All rights reserved.
//

import Foundation
import UIKit

extension UIDevice {
	public static var deviceId: String {
		guard let bundleId = Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String else { return "" }
		let account = "incoding"
		let data = Keychain.loadDataForUserAccount(userAccount: account, inService: bundleId)
		var deviceId = data?[kSecValueData as String] as? String
		if deviceId == nil {
			deviceId = UIDevice.current.identifierForVendor?.uuidString
		}
		if let id = deviceId {
			try? Keychain.saveData(data: [kSecValueData as String: id], forUserAccount: account, inService: bundleId)
		}
		
		return deviceId ?? ""
	}
}

// Copied from LockSmith https://github.com/matthewpalmer/LockSmith
public let KeychainDefaultService = Bundle.main.infoDictionary![String(kCFBundleIdentifierKey)] as? String ?? "cn.lefull.keychain.defaultService"

public typealias PerformRequestClosureType = (_ requestReference: CFDictionary, _ result: inout AnyObject?) -> (OSStatus)

// MARK: - Keychain
public struct Keychain {
	public static func loadDataForUserAccount(userAccount: String, inService service: String = KeychainDefaultService) -> [String: Any]? {
		struct ReadRequest: GenericPasswordSecureStorable, ReadableSecureStorable {
			let service: String
			let account: String
		}
		
		let request = ReadRequest(service: service, account: userAccount)
		return request.readFromSecureStore()?.data
	}
	
	public static func saveData(data: [String: Any], forUserAccount userAccount: String, inService service: String = KeychainDefaultService) throws {
		struct CreateRequest: GenericPasswordSecureStorable, CreateableSecureStorable {
			let service: String
			let account: String
			let data: [String: Any]
		}
		
		let request = CreateRequest(service: service, account: userAccount, data: data)
		return try request.createInSecureStore()
	}
	
	public static func deleteDataForUserAccount(userAccount: String, inService service: String = KeychainDefaultService) throws {
		struct DeleteRequest: GenericPasswordSecureStorable, DeleteableSecureStorable {
			let service: String
			let account: String
		}
		
		let request = DeleteRequest(service: service, account: userAccount)
		return try request.deleteFromSecureStore()
	}
	
	public static func updateData(data: [String: Any], forUserAccount userAccount: String, inService service: String = KeychainDefaultService) throws {
		struct UpdateRequest: GenericPasswordSecureStorable, CreateableSecureStorable {
			let service: String
			let account: String
			let data: [String: Any]
		}
		
		let request = UpdateRequest(service: service, account: userAccount, data: data)
		try request.updateInSecureStore()
	}
}

// MARK: - SecureStorable
/// The base protocol that indicates conforming types will have the ability to be stored in a secure storage container, such as the iOS keychain.
public protocol SecureStorable {
	var accessible: KeychainAccessibleOption? { get }
	var accessGroup: String? { get }
}

public extension SecureStorable {
	var accessible: KeychainAccessibleOption? { return nil }
	var accessGroup: String? { return nil }
	
	var secureStorableBaseStoragePropertyDictionary: [String: Any] {
		let dictionary = [
			String(kSecAttrAccessGroup): accessGroup,
			String(kSecAttrAccessible): accessible?.rawValue
		]
		
		return Dictionary(withoutOptionalValues: dictionary)
	}
	
	@discardableResult
	fileprivate func performSecureStorageAction(closure: PerformRequestClosureType, secureStoragePropertyDictionary: [String: Any]) throws -> [String: Any]? {
		var result: AnyObject?
		let request = secureStoragePropertyDictionary
		let requestReference = request as CFDictionary
		
		let status = closure(requestReference, &result)
		
		let statusCode = Int(status)
		
		if let error = KeychainError(fromStatusCode: statusCode) {
			throw error
		}
		
		// hmmmm... bit leaky
		if status != errSecSuccess {
			return nil
		}
		
		guard let dictionary = result as? NSDictionary else {
			return nil
		}
		
		if dictionary[String(kSecValueData)] as? NSData == nil {
			return nil
		}
		
		return result as? [String: Any]
	}
}

public extension SecureStorable where Self : InternetPasswordSecureStorable {
	fileprivate var internetPasswordBaseStoragePropertyDictionary: [String: Any] {
		var dictionary = [String: Any]()
		
		// add in whatever turns out to be required...
		dictionary[String(kSecAttrServer)] = server
		dictionary[String(kSecAttrPort)] = port
		dictionary[String(kSecAttrProtocol)] = internetProtocol.rawValue
		dictionary[String(kSecAttrAuthenticationType)] = authenticationType.rawValue
		dictionary[String(kSecAttrSecurityDomain)] = securityDomain
		dictionary[String(kSecAttrPath)] = path
		dictionary[String(kSecClass)] = KeychainSecurityClass.internetPassword.rawValue
		
		let toMergeWith = [
			accountSecureStoragePropertyDictionary,
			describableSecureStoragePropertyDictionary,
			commentableSecureStoragePropertyDictionary,
			creatorDesignatableSecureStoragePropertyDictionary,
			typeDesignatableSecureStoragePropertyDictionary,
			isInvisibleSecureStoragePropertyDictionary,
			isNegativeSecureStoragePropertyDictionary
		]
		
		for dict in toMergeWith {
			dictionary = Dictionary(initial: dictionary, toMerge: dict)
		}
		
		return dictionary
	}
}

public protocol AccountBasedSecureStorable {
	/// The account that the stored value will belong to
	var account: String { get }
}

public extension AccountBasedSecureStorable {
	fileprivate var accountSecureStoragePropertyDictionary: [String: Any] {
		return [String(kSecAttrAccount): account]
	}
}

public protocol AccountBasedSecureStorableResultType: AccountBasedSecureStorable, SecureStorableResultType {}

public extension AccountBasedSecureStorableResultType {
	var account: String {
		return resultDictionary[String(kSecAttrAccount)] as! String
	}
}

public protocol DescribableSecureStorable {
	/// A description of the item in the secure storage container.
	var description: String? { get }
}

public extension DescribableSecureStorable {
	var description: String? { return nil }
	
	fileprivate var describableSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [
			String(kSecAttrDescription): description
			])
	}
}

public protocol DescribableSecureStorableResultType: DescribableSecureStorable, SecureStorableResultType {}

public extension DescribableSecureStorableResultType {
	var description: String? {
		return resultDictionary[String(kSecAttrDescription)] as? String
	}
}

public protocol CommentableSecureStorable {
	/// A comment attached to the item in the secure storage container.
	var comment: String? { get }
}

public extension CommentableSecureStorable {
	var comment: String? { return nil }
	
	fileprivate var commentableSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [
			String(kSecAttrComment): comment
			])
	}
}

public protocol CommentableSecureStorableResultType: CommentableSecureStorable, SecureStorableResultType {}

public extension CommentableSecureStorableResultType {
	var comment: String? {
		return resultDictionary[String(kSecAttrComment)] as? String
	}
}

public protocol CreatorDesignatableSecureStorable {
	/// The creator of the item in the secure storage container.
	var creator: UInt? { get }
}

public extension CreatorDesignatableSecureStorable {
	var creator: UInt? { return nil }
	
	fileprivate var creatorDesignatableSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [String(kSecAttrCreator): creator])
	}
}

public protocol CreatorDesignatableSecureStorableResultType: CreatorDesignatableSecureStorable, SecureStorableResultType {}

public extension CreatorDesignatableSecureStorableResultType {
	var creator: UInt? {
		return resultDictionary[String(kSecAttrCreator)] as? UInt
	}
}

public protocol LabellableSecureStorable {
	/// A label for the item in the secure storage container.
	var label: String? { get }
}

public extension LabellableSecureStorable {
	var label: String? { return nil }
	
	fileprivate var labellableSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [String(kSecAttrLabel): label])
	}
}

public protocol LabellableSecureStorableResultType: LabellableSecureStorable, SecureStorableResultType {}

public extension LabellableSecureStorableResultType {
	var label: String? {
		return resultDictionary[String(kSecAttrLabel)] as? String
	}
}

public protocol TypeDesignatableSecureStorable {
	/// The type of the stored item
	var type: UInt? { get }
}

public extension TypeDesignatableSecureStorable {
	var type: UInt? { return nil }
	
	fileprivate var typeDesignatableSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [String(kSecAttrType): type])
	}
}

public protocol TypeDesignatableSecureStorableResultType: TypeDesignatableSecureStorable, SecureStorableResultType {}

public extension TypeDesignatableSecureStorableResultType {
	var type: UInt? {
		return resultDictionary[String(kSecAttrType)] as? UInt
	}
}

public protocol IsInvisibleAssignableSecureStorable {
	var isInvisible: Bool? { get }
}

public extension IsInvisibleAssignableSecureStorable {
	var isInvisible: Bool? { return nil }
	
	fileprivate var isInvisibleSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [String(kSecAttrIsInvisible): isInvisible])
	}
}

public protocol IsInvisibleAssignableSecureStorableResultType: IsInvisibleAssignableSecureStorable, SecureStorableResultType {}

public extension IsInvisibleAssignableSecureStorableResultType {
	var isInvisible: Bool? {
		return resultDictionary[String(kSecAttrIsInvisible)] as? Bool
	}
}

public protocol IsNegativeAssignableSecureStorable {
	var isNegative: Bool? { get }
}

public extension IsNegativeAssignableSecureStorable {
	var isNegative: Bool? { return nil }
	
	fileprivate var isNegativeSecureStoragePropertyDictionary: [String: Any] {
		return Dictionary(withoutOptionalValues: [String(kSecAttrIsNegative): isNegative])
	}
}

public protocol IsNegativeAssignableSecureStorableResultType: IsNegativeAssignableSecureStorable, SecureStorableResultType {
}

public extension IsNegativeAssignableSecureStorableResultType {
	var isNegative: Bool? {
		return resultDictionary[String(kSecAttrIsNegative)] as? Bool
	}
}

// MARK: - GenericPasswordSecureStorable
/// The protocol that indicates a type conforms to the requirements of a generic password item in a secure storage container.
/// Generic passwords are the most common types of things that are stored securely.
public protocol GenericPasswordSecureStorable: AccountBasedSecureStorable, DescribableSecureStorable, CommentableSecureStorable, CreatorDesignatableSecureStorable, LabellableSecureStorable, TypeDesignatableSecureStorable, IsInvisibleAssignableSecureStorable, IsNegativeAssignableSecureStorable {
	
	/// The service to which the type belongs
	var service: String { get }
	
	// Optional properties
	var generic: NSData? { get }
}

// Add extension to allow for optional properties in protocol
public extension GenericPasswordSecureStorable {
	var generic: NSData? { return nil}
}

// dear god what have i done...
public protocol GenericPasswordSecureStorableResultType: GenericPasswordSecureStorable, AccountBasedSecureStorableResultType, DescribableSecureStorableResultType, CommentableSecureStorableResultType, CreatorDesignatableSecureStorableResultType, LabellableSecureStorableResultType, TypeDesignatableSecureStorableResultType, IsInvisibleAssignableSecureStorableResultType, IsNegativeAssignableSecureStorableResultType {}

public extension GenericPasswordSecureStorableResultType {
	var service: String {
		return resultDictionary[String(kSecAttrService)] as! String
	}
	
	var generic: NSData? {
		return resultDictionary[String(kSecAttrGeneric)] as? NSData
	}
}

public extension SecureStorable where Self : GenericPasswordSecureStorable {
	fileprivate var genericPasswordBaseStoragePropertyDictionary: [String: Any] {
		var dictionary = [String: Any?]()
		
		dictionary[String(kSecAttrService)] = service
		dictionary[String(kSecAttrGeneric)] = generic
		dictionary[String(kSecClass)] = KeychainSecurityClass.genericPassword.rawValue
		
		dictionary = Dictionary(initial: dictionary, toMerge: describableSecureStoragePropertyDictionary)
		
		let toMergeWith = [
			secureStorableBaseStoragePropertyDictionary,
			accountSecureStoragePropertyDictionary,
			describableSecureStoragePropertyDictionary,
			commentableSecureStoragePropertyDictionary,
			creatorDesignatableSecureStoragePropertyDictionary,
			typeDesignatableSecureStoragePropertyDictionary,
			labellableSecureStoragePropertyDictionary,
			isInvisibleSecureStoragePropertyDictionary,
			isNegativeSecureStoragePropertyDictionary
		]
		
		for dict in toMergeWith {
			dictionary = Dictionary(initial: dictionary, toMerge: dict)
		}
		
		return Dictionary(withoutOptionalValues: dictionary)
	}
}

// MARK: - InternetPasswordSecureStorable
/// A protocol that indicates a type conforms to the requirements of an internet password in a secure storage container.
public protocol InternetPasswordSecureStorable: AccountBasedSecureStorable, DescribableSecureStorable, CommentableSecureStorable, CreatorDesignatableSecureStorable, TypeDesignatableSecureStorable, IsInvisibleAssignableSecureStorable, IsNegativeAssignableSecureStorable {
	var server: String { get }
	var port: Int { get }
	var internetProtocol: KeychainInternetProtocol { get }
	var authenticationType: KeychainInternetAuthenticationType { get }
	var securityDomain: String? { get }
	var path: String? { get }
}

public extension InternetPasswordSecureStorable {
	var securityDomain: String? { return nil }
	var path: String? { return nil }
}

public protocol InternetPasswordSecureStorableResultType: AccountBasedSecureStorableResultType, DescribableSecureStorableResultType, CommentableSecureStorableResultType, CreatorDesignatableSecureStorableResultType, TypeDesignatableSecureStorableResultType, IsInvisibleAssignableSecureStorableResultType, IsNegativeAssignableSecureStorableResultType {}

public extension InternetPasswordSecureStorableResultType {
	private func stringFromResultDictionary(key: CFString) -> String? {
		return resultDictionary[String(key)] as? String
	}
	
	var server: String {
		return stringFromResultDictionary(key: kSecAttrServer)!
	}
	
	var port: Int {
		return resultDictionary[String(kSecAttrPort)] as! Int
	}
	
	var internetProtocol: KeychainInternetProtocol {
		return KeychainInternetProtocol(rawValue: stringFromResultDictionary(key: kSecAttrProtocol)!)!
	}
	
	var authenticationType: KeychainInternetAuthenticationType {
		return KeychainInternetAuthenticationType(rawValue:  stringFromResultDictionary(key: kSecAttrAuthenticationType)!)!
	}
	
	var securityDomain: String? {
		return stringFromResultDictionary(key: kSecAttrSecurityDomain)
	}
	
	var path: String? {
		return stringFromResultDictionary(key: kSecAttrPath)
	}
}

// MARK: - CertificateSecureStorable

public protocol CertificateSecureStorable: SecureStorable {}

// MARK: - KeySecureStorable

public protocol KeySecureStorable: SecureStorable {}

// MARK: - CreateableSecureStorable

/// Conformance to this protocol indicates that your type is able to be created and saved to a secure storage container.
public protocol CreateableSecureStorable: SecureStorable {
	var data: [String: Any] { get }
	var performCreateRequestClosure: PerformRequestClosureType { get }
	func createInSecureStore() throws
	func updateInSecureStore() throws
}

// MARK: - ReadableSecureStorable
/// Conformance to this protocol indicates that your type is able to be read from a secure storage container.
public protocol ReadableSecureStorable: SecureStorable {
	var performReadRequestClosure: PerformRequestClosureType { get }
	func readFromSecureStore() -> SecureStorableResultType?
}

public extension ReadableSecureStorable {
	var performReadRequestClosure: PerformRequestClosureType {
		return { (requestReference: CFDictionary, result: inout AnyObject?) in
			return withUnsafeMutablePointer(to: &result) { SecItemCopyMatching(requestReference, UnsafeMutablePointer($0)) }
		}
	}
	
	func readFromSecureStore() -> SecureStorableResultType? {
		// This must be implemented here so that we can properly override it in the type-specific implementations
		return nil
	}
}

public extension ReadableSecureStorable where Self : GenericPasswordSecureStorable {
	var asReadableSecureStoragePropertyDictionary: [String: Any] {
		var old = genericPasswordBaseStoragePropertyDictionary
		old[String(kSecReturnData)] = kCFBooleanTrue
		old[String(kSecMatchLimit)] = kSecMatchLimitOne
		old[String(kSecReturnAttributes)] = kCFBooleanTrue
		
		return old
	}
}

public extension ReadableSecureStorable where Self : InternetPasswordSecureStorable {
	var asReadableSecureStoragePropertyDictionary: [String: Any] {
		var old = internetPasswordBaseStoragePropertyDictionary
		old[String(kSecReturnData)] = kCFBooleanTrue
		old[String(kSecMatchLimit)] = kSecMatchLimitOne
		old[String(kSecReturnAttributes)] = kCFBooleanTrue
		return old
	}
}

struct GenericPasswordResult: GenericPasswordSecureStorableResultType {
	var resultDictionary: [String: Any]
}

public extension ReadableSecureStorable where Self : GenericPasswordSecureStorable {
	func readFromSecureStore() -> GenericPasswordSecureStorableResultType? {
		do {
			if let result = try performSecureStorageAction(closure: performReadRequestClosure, secureStoragePropertyDictionary: asReadableSecureStoragePropertyDictionary) {
				return GenericPasswordResult(resultDictionary: result)
			} else {
				return nil
			}
		} catch {
			return nil
		}
	}
}

public extension ReadableSecureStorable where Self : InternetPasswordSecureStorable {
	func readFromSecureStore() -> InternetPasswordSecureStorableResultType? {
		do {
			if let result = try performSecureStorageAction(closure: performReadRequestClosure, secureStoragePropertyDictionary: asReadableSecureStoragePropertyDictionary) {
				return InternetPasswordResult(resultDictionary: result)
			} else {
				return nil
			}
		} catch {
			return nil
		}
	}
}


// MARK: - DeleteableSecureStorable
/// Conformance to this protocol indicates that your type is able to be deleted from a secure storage container.
public protocol DeleteableSecureStorable: SecureStorable {
	var performDeleteRequestClosure: PerformRequestClosureType { get }
	func deleteFromSecureStore() throws
}

// MARK: - Default property dictionaries

extension CreateableSecureStorable {
	func updateInSecureStore(query: [String: Any]) throws {
		var attributesToUpdate = query
		attributesToUpdate[String(kSecClass)] = nil
		
		let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
		
		if let error = KeychainError(fromStatusCode: Int(status)) {
			if error == .notFound || error == .notAvailable {
				try self.createInSecureStore()
			} else {
				throw error
			}
		} else {
			if status != errSecSuccess {
				throw KeychainError.undefined
			}
		}
	}
}

public extension CreateableSecureStorable where Self : GenericPasswordSecureStorable {
	var asCreateableSecureStoragePropertyDictionary: [String: Any] {
		var old = genericPasswordBaseStoragePropertyDictionary
		old[String(kSecValueData)] = NSKeyedArchiver.archivedData(withRootObject: data)
		return old
	}
}

public extension CreateableSecureStorable where Self : GenericPasswordSecureStorable {
	func createInSecureStore() throws {
		try performSecureStorageAction(closure: performCreateRequestClosure, secureStoragePropertyDictionary: asCreateableSecureStoragePropertyDictionary)
	}
	func updateInSecureStore() throws {
		try self.updateInSecureStore(query: self.asCreateableSecureStoragePropertyDictionary)
	}
}

public extension CreateableSecureStorable where Self : InternetPasswordSecureStorable {
	var asCreateableSecureStoragePropertyDictionary: [String: Any] {
		var old = internetPasswordBaseStoragePropertyDictionary
		old[String(kSecValueData)] = NSKeyedArchiver.archivedData(withRootObject: data)
		return old
	}
}

public extension CreateableSecureStorable {
	var performCreateRequestClosure: PerformRequestClosureType {
		return { (requestReference: CFDictionary, result: inout AnyObject?) in
			return withUnsafeMutablePointer(to: &result) { mutablePointer in
				SecItemAdd(requestReference, mutablePointer)
			}
		}
	}
}

public extension CreateableSecureStorable where Self : InternetPasswordSecureStorable {
	func createInSecureStore() throws {
		try performSecureStorageAction(closure: performCreateRequestClosure, secureStoragePropertyDictionary: asCreateableSecureStoragePropertyDictionary)
	}
	func updateInSecureStore() throws {
		try self.updateInSecureStore(query: self.asCreateableSecureStoragePropertyDictionary)
	}
}

public extension DeleteableSecureStorable {
	var performDeleteRequestClosure: PerformRequestClosureType {
		return { (requestReference, _) in
			return SecItemDelete(requestReference)
		}
	}
}

public extension DeleteableSecureStorable where Self : GenericPasswordSecureStorable {
	var asDeleteableSecureStoragePropertyDictionary: [String: Any] {
		return genericPasswordBaseStoragePropertyDictionary
	}
}

public extension DeleteableSecureStorable where Self : InternetPasswordSecureStorable {
	var asDeleteableSecureStoragePropertyDictionary: [String: Any] {
		return internetPasswordBaseStoragePropertyDictionary
	}
}

public extension DeleteableSecureStorable where Self : GenericPasswordSecureStorable {
	func deleteFromSecureStore() throws {
		try performSecureStorageAction(closure: performDeleteRequestClosure, secureStoragePropertyDictionary: asDeleteableSecureStoragePropertyDictionary)
	}
}

public extension DeleteableSecureStorable where Self : InternetPasswordSecureStorable {
	func deleteFromSecureStore() throws {
		try performSecureStorageAction(closure: performDeleteRequestClosure, secureStoragePropertyDictionary: asDeleteableSecureStoragePropertyDictionary)
	}
}

// MARK: ResultTypes
public protocol SecureStorableResultType: SecureStorable {
	var resultDictionary: [String: Any] { get }
	var data: [String: Any]? { get }
}

struct InternetPasswordResult: InternetPasswordSecureStorableResultType {
	var resultDictionary: [String: Any]
}

public extension SecureStorableResultType {
	var resultDictionary: [String: Any] {
		return [String: Any]()
	}
	
	var data: [String: Any]? {
		guard let aData = resultDictionary[String(kSecValueData)] as? NSData else {
			return nil
		}
		
		return NSKeyedUnarchiver.unarchiveObject(with: aData as Data) as? [String: Any]
	}
}

// MARK: Accessible
public enum KeychainAccessibleOption: RawRepresentable {
	case whenUnlocked, afterFirstUnlock, always, whenUnlockedThisDeviceOnly, afterFirstUnlockThisDeviceOnly, alwaysThisDeviceOnly, whenPasscodeSetThisDeviceOnly
	
	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecAttrAccessibleWhenUnlocked):
			self = .whenUnlocked
		case String(kSecAttrAccessibleAfterFirstUnlock):
			self = .afterFirstUnlock
		case String(kSecAttrAccessibleAlways):
			self = .always
		case String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly):
			self = .whenUnlockedThisDeviceOnly
		case String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly):
			self = .afterFirstUnlockThisDeviceOnly
		case String(kSecAttrAccessibleAlwaysThisDeviceOnly):
			self = .alwaysThisDeviceOnly
		case String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly):
			self = .whenPasscodeSetThisDeviceOnly
		default:
			self = .whenUnlocked
		}
	}
	
	public var rawValue: String {
		switch self {
		case .whenUnlocked:
			return String(kSecAttrAccessibleWhenUnlocked)
		case .afterFirstUnlock:
			return String(kSecAttrAccessibleAfterFirstUnlock)
		case .always:
			return String(kSecAttrAccessibleAlways)
		case .whenPasscodeSetThisDeviceOnly:
			return String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
		case .whenUnlockedThisDeviceOnly:
			return String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
		case .afterFirstUnlockThisDeviceOnly:
			return String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
		case .alwaysThisDeviceOnly:
			return String(kSecAttrAccessibleAlwaysThisDeviceOnly)
		}
	}
}

// MARK: Keychain Error
public enum KeychainError: String, Error {
	case allocate = "Failed to allocate memory."
	case authFailed = "Authorization/Authentication failed."
	case decode = "Unable to decode the provided data."
	case duplicate = "The item already exists."
	case interactionNotAllowed = "Interaction with the Security Server is not allowed."
	case noError = "No error."
	case notAvailable = "No trust results are available."
	case notFound = "The item cannot be found."
	case param = "One or more parameters passed to the function were not valid."
	case requestNotSet = "The request was not set"
	case typeNotFound = "The type was not found"
	case unableToClear = "Unable to clear the keychain"
	case undefined = "An undefined error occurred"
	case unimplemented = "Function or operation not implemented."
	
	init?(fromStatusCode code: Int) {
		switch code {
		case Int(errSecAllocate):
			self = .allocate
		case Int(errSecAuthFailed):
			self = .authFailed
		case Int(errSecDecode):
			self = .decode
		case Int(errSecDuplicateItem):
			self = .duplicate
		case Int(errSecInteractionNotAllowed):
			self = .interactionNotAllowed
		case Int(errSecItemNotFound):
			self = .notFound
		case Int(errSecNotAvailable):
			self = .notAvailable
		case Int(errSecParam):
			self = .param
		case Int(errSecUnimplemented):
			self = .unimplemented
		default:
			return nil
		}
	}
}

public extension Dictionary {
	init(withoutOptionalValues initial: Dictionary<Key, Value?>) {
		self = [Key: Value]()
		for pair in initial {
			if pair.1 != nil {
				self[pair.0] = pair.1!
			}
		}
	}
	
	init(pairs: [(Key, Value)]) {
		self = [Key: Value]()
		pairs.forEach { (k, v) -> () in
			self[k] = v
		}
	}
	
	init(initial: Dictionary<Key, Value>, toMerge: Dictionary<Key, Value>) {
		self = Dictionary<Key, Value>()
		
		for pair in initial {
			self[pair.0] = pair.1
		}
		
		for pair in toMerge {
			self[pair.0] = pair.1
		}
	}
}

// MARK: Security Class
public enum KeychainSecurityClass: RawRepresentable {
	case genericPassword, internetPassword, certificate, key, identity
	
	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecClassGenericPassword):
			self = .genericPassword
		case String(kSecClassInternetPassword):
			self = .internetPassword
		case String(kSecClassCertificate):
			self = .certificate
		case String(kSecClassKey):
			self = .key
		case String(kSecClassIdentity):
			self = .identity
		default:
			self = .genericPassword
		}
	}
	
	public var rawValue: String {
		switch self {
		case .genericPassword:
			return String(kSecClassGenericPassword)
		case .internetPassword:
			return String(kSecClassInternetPassword)
		case .certificate:
			return String(kSecClassCertificate)
		case .key:
			return String(kSecClassKey)
		case .identity:
			return String(kSecClassIdentity)
		}
	}
}

public enum KeychainInternetAuthenticationType: RawRepresentable {
	case ntlm, msn, dpa, rpa, httpBasic, httpDigest, htmlForm, `default`
	
	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecAttrAuthenticationTypeNTLM):
			self = .ntlm
		case String(kSecAttrAuthenticationTypeMSN):
			self = .msn
		case String(kSecAttrAuthenticationTypeDPA):
			self = .dpa
		case String(kSecAttrAuthenticationTypeRPA):
			self = .rpa
		case String(kSecAttrAuthenticationTypeHTTPBasic):
			self = .httpBasic
		case String(kSecAttrAuthenticationTypeHTTPDigest):
			self = .httpDigest
		case String(kSecAttrAuthenticationTypeHTMLForm):
			self = .htmlForm
		case String(kSecAttrAuthenticationTypeDefault):
			self = .default
		default:
			self = .default
		}
	}
	
	public var rawValue: String {
		switch self {
		case .ntlm:
			return String(kSecAttrAuthenticationTypeNTLM)
		case .msn:
			return String(kSecAttrAuthenticationTypeMSN)
		case .dpa:
			return String(kSecAttrAuthenticationTypeDPA)
		case .rpa:
			return String(kSecAttrAuthenticationTypeRPA)
		case .httpBasic:
			return String(kSecAttrAuthenticationTypeHTTPBasic)
		case .httpDigest:
			return String(kSecAttrAuthenticationTypeHTTPDigest)
		case .htmlForm:
			return String(kSecAttrAuthenticationTypeHTMLForm)
		case .default:
			return String(kSecAttrAuthenticationTypeDefault)
		}
	}
}

public enum KeychainInternetProtocol: RawRepresentable {
	case ftp, ftpAccount, http, irc, nntp, pop3, smtp, socks, imap, ldap, appleTalk, afp, telnet, ssh, ftps, https, httpProxy, httpsProxy, ftpProxy, smb, rtsp, rtspProxy, daap, eppc, ipp, nntps, ldaps, telnetS, imaps, ircs, pop3S
	
	public init?(rawValue: String) {
		switch rawValue {
		case String(kSecAttrProtocolFTP):
			self = .ftp
		case String(kSecAttrProtocolFTPAccount):
			self = .ftpAccount
		case String(kSecAttrProtocolHTTP):
			self = .http
		case String(kSecAttrProtocolIRC):
			self = .irc
		case String(kSecAttrProtocolNNTP):
			self = .nntp
		case String(kSecAttrProtocolPOP3):
			self = .pop3
		case String(kSecAttrProtocolSMTP):
			self = .smtp
		case String(kSecAttrProtocolSOCKS):
			self = .socks
		case String(kSecAttrProtocolIMAP):
			self = .imap
		case String(kSecAttrProtocolLDAP):
			self = .ldap
		case String(kSecAttrProtocolAppleTalk):
			self = .appleTalk
		case String(kSecAttrProtocolAFP):
			self = .afp
		case String(kSecAttrProtocolTelnet):
			self = .telnet
		case String(kSecAttrProtocolSSH):
			self = .ssh
		case String(kSecAttrProtocolFTPS):
			self = .ftps
		case String(kSecAttrProtocolHTTPS):
			self = .https
		case String(kSecAttrProtocolHTTPProxy):
			self = .httpProxy
		case String(kSecAttrProtocolHTTPSProxy):
			self = .httpsProxy
		case String(kSecAttrProtocolFTPProxy):
			self = .ftpProxy
		case String(kSecAttrProtocolSMB):
			self = .smb
		case String(kSecAttrProtocolRTSP):
			self = .rtsp
		case String(kSecAttrProtocolRTSPProxy):
			self = .rtspProxy
		case String(kSecAttrProtocolDAAP):
			self = .daap
		case String(kSecAttrProtocolEPPC):
			self = .eppc
		case String(kSecAttrProtocolIPP):
			self = .ipp
		case String(kSecAttrProtocolNNTPS):
			self = .nntps
		case String(kSecAttrProtocolLDAPS):
			self = .ldaps
		case String(kSecAttrProtocolTelnetS):
			self = .telnetS
		case String(kSecAttrProtocolIMAPS):
			self = .imaps
		case String(kSecAttrProtocolIRCS):
			self = .ircs
		case String(kSecAttrProtocolPOP3S):
			self = .pop3S
		default:
			self = .http
		}
	}
	
	public var rawValue: String {
		switch self {
		case .ftp:
			return String(kSecAttrProtocolFTP)
		case .ftpAccount:
			return String(kSecAttrProtocolFTPAccount)
		case .http:
			return String(kSecAttrProtocolHTTP)
		case .irc:
			return String(kSecAttrProtocolIRC)
		case .nntp:
			return String(kSecAttrProtocolNNTP)
		case .pop3:
			return String(kSecAttrProtocolPOP3)
		case .smtp:
			return String(kSecAttrProtocolSMTP)
		case .socks:
			return String(kSecAttrProtocolSOCKS)
		case .imap:
			return String(kSecAttrProtocolIMAP)
		case .ldap:
			return String(kSecAttrProtocolLDAP)
		case .appleTalk:
			return String(kSecAttrProtocolAppleTalk)
		case .afp:
			return String(kSecAttrProtocolAFP)
		case .telnet:
			return String(kSecAttrProtocolTelnet)
		case .ssh:
			return String(kSecAttrProtocolSSH)
		case .ftps:
			return String(kSecAttrProtocolFTPS)
		case .https:
			return String(kSecAttrProtocolHTTPS)
		case .httpProxy:
			return String(kSecAttrProtocolHTTPProxy)
		case .httpsProxy:
			return String(kSecAttrProtocolHTTPSProxy)
		case .ftpProxy:
			return String(kSecAttrProtocolFTPProxy)
		case .smb:
			return String(kSecAttrProtocolSMB)
		case .rtsp:
			return String(kSecAttrProtocolRTSP)
		case .rtspProxy:
			return String(kSecAttrProtocolRTSPProxy)
		case .daap:
			return String(kSecAttrProtocolDAAP)
		case .eppc:
			return String(kSecAttrProtocolEPPC)
		case .ipp:
			return String(kSecAttrProtocolIPP)
		case .nntps:
			return String(kSecAttrProtocolNNTPS)
		case .ldaps:
			return String(kSecAttrProtocolLDAPS)
		case .telnetS:
			return String(kSecAttrProtocolTelnetS)
		case .imaps:
			return String(kSecAttrProtocolIMAPS)
		case .ircs:
			return String(kSecAttrProtocolIRCS)
		case .pop3S:
			return String(kSecAttrProtocolPOP3S)
		}
	}
}
