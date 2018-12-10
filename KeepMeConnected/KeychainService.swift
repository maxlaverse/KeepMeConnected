import Cocoa
import os.log

class KeychainService : NSObject {
    
    class func getString(forKey : String) -> String?{
        var query = keychainQueryDictionary(key: forKey)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != noErr {
            if let err = SecCopyErrorMessageString(status, nil) {
                os_log("Error while reading password from Keychain: %d %s",status,err as String)
            }
            return nil
            
        }
        os_log("Queried Keychain for '%s' with status %d",forKey, status)
        let d = result as? Data
        return String(data: d!, encoding: .utf8)!
    }
    
    class func setString(forKey : String, value : String) {
        var query = keychainQueryDictionary(key: forKey)
        query[kSecValueData as String] = value.data(using: .utf8)
        
        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            os_log("Successfully added password to Keychain")
        } else if status == errSecDuplicateItem {
            updateString(forKey: forKey, value: value)
        } else {
            os_log("Error while adding password to Keychain: %d",status)
        }
    }
    
    class func updateString(forKey : String, value : String) {
        let updateDictionary = [(kSecValueData as String):value.data(using: .utf8)]
        let query = keychainQueryDictionary(key: forKey)
        let status: OSStatus = SecItemUpdate(query as CFDictionary, updateDictionary as CFDictionary)
        if status == errSecSuccess {
            os_log("Successfully updated password in Keychain")
        }else{
            if let err = SecCopyErrorMessageString(status, nil) {
                os_log("Error while updating password in Keychain: %d %s",status,err as String)
            }
        }
    }

    class func deleteString(forKey : String) {
        let query = keychainQueryDictionary(key: forKey)
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            os_log("Successfully removed password in Keychain")
        }else{
            if let err = SecCopyErrorMessageString(status, nil) {
                os_log("Error while removing password in Keychain: %d %s",status,err as String)
            }
        }
    }
    
    class func keychainQueryDictionary(key :String) -> [String:Any] {
        var queryDictionary: [String:Any] = [(kSecClass as String):kSecClassGenericPassword]
        
        let encodedIdentifier: Data? = key.data(using: String.Encoding.utf8)
        
        // Uniquely identify this keychain accessor
        queryDictionary[kSecAttrService as String] = Bundle.main.bundleIdentifier!
        queryDictionary[kSecAttrGeneric as String] = encodedIdentifier
        queryDictionary[kSecAttrAccount as String] = encodedIdentifier
        
        return queryDictionary
    }
}
