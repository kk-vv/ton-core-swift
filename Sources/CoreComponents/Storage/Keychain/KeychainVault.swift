import Foundation

public enum KeychainVaultError: Swift.Error {
  case noItemFound
  case unexpectedData
  case unhandledError(status: OSStatus)
}

public protocol KeychainVault {
  func readValue<T: Codable>(_ item: KeychainQueryable) throws -> T
  func saveValue<T: Codable>(_ value: T, to item: KeychainQueryable) throws
  func deleteItem(_ item: KeychainQueryable) throws
}

public struct KeychainVaultImplementation: KeychainVault {
  
  private let keychain: Keychain
  
  public init(keychain: Keychain) {
    self.keychain = keychain
  }
  
  public func readValue<T: Codable>(_ item: KeychainQueryable) throws -> T {
    var query = try item.query
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = kCFBooleanTrue
    
    let response = keychain.fetch(query)
    
    guard response.status != errSecItemNotFound else {
      throw KeychainVaultError.noItemFound
    }
    
    guard response.status == noErr else {
      throw KeychainVaultError.unhandledError(status: response.status)
    }
    
    guard let data = response.result as? Data,
          let value = try? JSONDecoder().decode(T.self, from: data) else {
      throw KeychainVaultError.unexpectedData
    }
    
    return value
  }
  
  public func saveValue<T: Codable>(_ value: T, to item: KeychainQueryable) throws {
    let data = try JSONEncoder().encode(value)
    
    do {
      _ = try readValue(item) as T
      let attributes: [String: AnyObject] = [
        kSecValueData as String: data as AnyObject
      ]
      let status = keychain.update(try item.query, with: attributes)
      guard status == noErr else {
        throw KeychainVaultError.unhandledError(status: status)
      }
    } catch KeychainVaultError.noItemFound {
      var query = try item.query
      query[kSecValueData as String] = data as AnyObject
      
      let status = keychain.add(query)
      guard status == noErr else {
        throw KeychainVaultError.unhandledError(status: status)
      }
    } catch {
      throw error
    }
  }
  
  public func deleteItem(_ item: KeychainQueryable) throws {
    let status = keychain.delete(try item.query)
    guard status == noErr || status == errSecItemNotFound else {
      throw KeychainVaultError.unhandledError(status: status)
    }
  }
}
