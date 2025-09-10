//
//  KeychainManager.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 09.09.2025.
//

import Foundation
import Security

/// Secure storage manager for sensitive data using the macOS Keychain.
/// Provides thread-safe operations for storing and retrieving API keys and other secrets.
/// Automatically isolates debug and release environments with different service identifiers.
struct KeychainManager {
    /// Shared singleton instance for keychain operations
    static let shared = KeychainManager()
    
    private init() {}
    
    private let service: String = {
        let bundleId = Bundle.main.bundleIdentifier!
        #if DEBUG
        return "\(bundleId).debug"
        #else
        return bundleId
        #endif
    }()
    
    /// Saves a string value securely in the keychain.
    /// Overwrites any existing value for the same key.
    /// - Parameters:
    ///   - key: Unique identifier for the stored value
    ///   - value: String data to store securely
    /// - Throws: KeychainError if the save operation fails
    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Delete any existing item first
        try? delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Retrieves a string value from the keychain.
    /// - Parameter key: Unique identifier for the stored value
    /// - Returns: Stored string value, nil if not found
    /// - Throws: KeychainError if the retrieval operation fails
    func retrieve(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return string
    }
    
    /// Removes a stored value from the keychain.
    /// - Parameter key: Unique identifier for the value to remove
    /// - Throws: KeychainError if the deletion fails (ignores "not found" errors)
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

/// Errors that can occur during keychain operations.
/// Provides detailed error information including system status codes.
enum KeychainError: LocalizedError {
    case invalidData
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .saveFailed(let status):
            return "Failed to save to keychain (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve from keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from keychain (status: \(status))"
        }
    }
}
