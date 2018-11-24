import Cocoa
import ServiceManagement
import os.log

let KEY_AUTO_START = "KMCAutoStart"
let KEY_EMAIL = "KMCEmail"
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
        print(Array(UserDefaults.standard.dictionaryRepresentation().keys).count)
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

    func getUserEmail() -> String?{
        return UserDefaults.standard.string(forKey: KEY_EMAIL)
    }

    func setUserEmail(_ email : String) -> Bool {
        if !isValidUserEmail(email){
            return false
        }
        UserDefaults.standard.set(email, forKey: KEY_EMAIL)
        return true
    }

    func getRunAtLogin() -> Bool{
        return UserDefaults.standard.bool(forKey: KEY_AUTO_START)
    }

    func setRunAtLogin(_ runAtLogin : Bool) {
        UserDefaults.standard.set(runAtLogin, forKey: KEY_AUTO_START)
        SMLoginItemSetEnabled(Bundle.main.bundleIdentifier! as CFString, runAtLogin)
    }

    func shouldShowNotifications() -> Bool{
        return UserDefaults.standard.bool(forKey: KEY_SHOW_NOTIFICATIONS)
    }

    func setShowNotifications(_ showNotifications : Bool) {
        UserDefaults.standard.set(showNotifications, forKey: KEY_SHOW_NOTIFICATIONS)
    }

    func isValidUserEmail(_ textStr:String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: textStr)
    }

    func isValidPortalURL(_ textStr:String) -> Bool {
        if let u = URL(string: textStr), u.scheme == "https"{
            return true
        }else{
            return false
        }
    }

}
