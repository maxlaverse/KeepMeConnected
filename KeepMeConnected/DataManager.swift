import Cocoa
import ServiceManagement
import os.log

let KEY_AUTO_START = "KMCAutoStart"
let KEY_EMAIL = "KMCEmail"
let KEY_USERNAME = "KMCUsername"
let KEY_DOMAIN = "KMCDomain"
let KEY_PORTAL_URL = "KMCPortalURL"
let KEY_SHOW_NOTIFICATIONS = "KMCShowNotifications"
let KEY_POLLING_RATE = "KMCPollingRate"
let KEY_PASSWORD = "password"

class DataManager : NSObject {
    static let sharedData = DataManager()

    override init() {
        super.init()
        setRunAtLogin(getRunAtLogin())

        let defaults = [KEY_SHOW_NOTIFICATIONS : true, KEY_POLLING_RATE : 60] as [String : Any]
        UserDefaults.standard.register(defaults: defaults)

        if !UserDefaults.standard.bool(forKey: "SUHasLaunchedBefore") {
            setRunAtLogin(true)
        }
    }

    func reset(){
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
        KeychainService.deleteString(forKey: KEY_PASSWORD)
    }

    func getPollingInterval() -> Double {
        return UserDefaults.standard.double(forKey: KEY_POLLING_RATE)
    }

    func setPollingInterval(_ rate : Double) {
        UserDefaults.standard.set(rate, forKey: KEY_POLLING_RATE)
    }

    func getUserPassword() -> String?{
        return KeychainService.getString(forKey: KEY_PASSWORD)
    }

    func setUserPassword(_ password : String) {
        KeychainService.setString(forKey: KEY_PASSWORD,value: password)
    }

    func getPortalURL() -> URL?{
        if let u = UserDefaults.standard.string(forKey: KEY_PORTAL_URL) {
            if !u.hasSuffix("/"){
                return URL(string: u + "/")
            }
            return URL(string: u)
        }
        return nil
    }

    func setPortalURL(_ server : String) -> Bool {
        if !isValidPortalURL(server){
            return false
        }
        UserDefaults.standard.set(server, forKey: KEY_PORTAL_URL)
        return true
    }

    func getUserName() -> String?{
        if UserDefaults.standard.string(forKey: KEY_USERNAME) == nil{
            if let email = UserDefaults.standard.string(forKey: KEY_EMAIL){
                let username = email.components(separatedBy: "@")[0]
                if !setUserName(username){
                    os_log("Could not setUserName")
                }
                return username
            }
        }
        return UserDefaults.standard.string(forKey: KEY_USERNAME)
    }

    func setUserName(_ username : String) -> Bool {
        if !isValidUserName(username){
            return false
        }
        UserDefaults.standard.set(username, forKey: KEY_USERNAME)
        return true
    }

    func getUserDomain() -> String?{
        if UserDefaults.standard.string(forKey: KEY_DOMAIN) == nil{
            if let email = UserDefaults.standard.string(forKey: KEY_EMAIL){
                let domain = email.components(separatedBy: "@")[1]
                if !setUserDomain(domain){
                    os_log("Could not setUserDomain")
                }
                return domain
            }
        }
        return UserDefaults.standard.string(forKey: KEY_DOMAIN)
    }

    func setUserDomain(_ domain : String) -> Bool {
        if !isValidUserDomain(domain){
            return false
        }
        UserDefaults.standard.set(domain, forKey: KEY_DOMAIN)
        return true
    }

    func getRunAtLogin() -> Bool{
        return UserDefaults.standard.bool(forKey: KEY_AUTO_START)
    }

    func setRunAtLogin(_ runAtLogin : Bool) {
        UserDefaults.standard.set(runAtLogin, forKey: KEY_AUTO_START)
        if !SMLoginItemSetEnabled("\(Bundle.main.bundleIdentifier!)Launcher" as CFString, runAtLogin){
            os_log("Failed to register application for auto-startup")
        }else{
            os_log("Successfully registered application for auto-startup")
        }
    }

    func shouldShowNotifications() -> Bool{
        return UserDefaults.standard.bool(forKey: KEY_SHOW_NOTIFICATIONS)
    }

    func setShowNotifications(_ showNotifications : Bool) {
        UserDefaults.standard.set(showNotifications, forKey: KEY_SHOW_NOTIFICATIONS)
    }

    func isValidUserName(_ textStr:String) -> Bool {
        let userNameRegexp = "[A-Z0-9a-z._%+-]+"
        let userNameTest = NSPredicate(format:"SELF MATCHES %@", userNameRegexp)
        return userNameTest.evaluate(with: textStr)
    }

    func isValidUserDomain(_ textStr:String) -> Bool {
        let userDomainRegexp = "[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let userDomainTest = NSPredicate(format:"SELF MATCHES %@", userDomainRegexp)
        return userDomainTest.evaluate(with: textStr)
    }

    func isValidPortalURL(_ textStr:String) -> Bool {
        if let u = URL(string: textStr), u.scheme == "https"{
            return true
        }else{
            return false
        }
    }

}
