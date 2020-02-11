import Cocoa
import Foundation
import os.log

enum WatchGuardLoginResponse {
    case Success
    case Failed(_ reason : String)
    case Error(_ reason : String)
}

enum WatchGuardLogoutResponse {
    case Success
    case Failed(_ reason : String)
    case Error(_ reason : String)
}

enum WatchGuardCheckStatusResponse {
    case Connected
    case NotConnected
    case Error(_ reason : String)
}

class WatchGuard: NSObject {
    static let UserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:63.0) Gecko/20100101 Firefox/63.0"
    
    func checkStatus(portalUrl: URL,handler: @escaping (_: WatchGuardCheckStatusResponse) -> Void){
        
        // Prepare request
        var request = URLRequest(url: URL(string: "\(portalUrl)wgcgi.cgi?action=fw_logon&fw_logon_type=status")!)
        request.timeoutInterval = 3
        
        // Headers
        request.addValue(WatchGuard.UserAgent, forHTTPHeaderField: "User-Agent")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if error != nil {
                handler(WatchGuardCheckStatusResponse.Error(error!.localizedDescription.dropSuffix(".")))
            }else{
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.url?.absoluteString.range(of:"success.shtml") != nil {
                        handler(WatchGuardCheckStatusResponse.Connected)
                    }else if httpResponse.url?.absoluteString.range(of:"logon.shtml") != nil {
                        handler(WatchGuardCheckStatusResponse.NotConnected)
                    }else{
                        handler(WatchGuardCheckStatusResponse.Error(String(format: "Unknown location '%@' (%d)",httpResponse.url!.absoluteString, httpResponse.statusCode)))
                    }
                }else{
                    handler(WatchGuardCheckStatusResponse.Error("No HTTPURLResponse was returned"))
                }
            }
        }
        task.resume()
    }
    
    func logon(portalUrl: URL,userName: String,userPassword: String,userDomain: String, handler: @escaping (_: WatchGuardLoginResponse) -> Void){
        // Prepare request
        var request = URLRequest(url: URL(string: "\(portalUrl)wgcgi.cgi")!)
        request.timeoutInterval = 3
        request.httpMethod = "POST"
        
        if let encodedUserDomain = userDomain.addingPercentEncoding(withAllowedCharacters:.alphanumerics),
            let encodedUserName = userName.addingPercentEncoding(withAllowedCharacters:.alphanumerics),
            let encodedUserPassword = userPassword.addingPercentEncoding(withAllowedCharacters:.alphanumerics) {

            // Body
            request.httpBody = "action=fw_logon&fw_domain=\(encodedUserDomain)&fw_logon_type=logon&fw_username=\(encodedUserName)&fw_password=\(encodedUserPassword)&lang=en-US&submit=Login".data(using: String.Encoding.ascii, allowLossyConversion: false)

            // Headers
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.addValue("*/*", forHTTPHeaderField: "Accept")
            request.addValue(WatchGuard.UserAgent, forHTTPHeaderField: "User-Agent")

            // Execute the request
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if error != nil {
                    handler(WatchGuardLoginResponse.Error(error!.localizedDescription.dropSuffix(".")))
                } else {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.url == portalUrl || httpResponse.url?.absoluteString.range(of:"success.shtml") != nil {
                            handler(WatchGuardLoginResponse.Success)
                        }else{
                            if let errcode = URLComponents(string: httpResponse.url!.absoluteString)?.queryItems?.filter({$0.name == "errcode"}).first?.value {
                                os_log("Error on logon. Error (%@) '%@'",errcode,WatchGuard.getErrorCodeStr(errcode))
                                handler(WatchGuardLoginResponse.Failed(WatchGuard.getErrorCodeStr(errcode)))
                            }else{
                                os_log("Error on logon. Wrong base '%@'",httpResponse.url!.absoluteString)
                                handler(WatchGuardLoginResponse.Error(String(format: "Missing errcode in redirection to '%@'",httpResponse.url!.absoluteString)))
                            }
                        }
                    }else{
                        handler(WatchGuardLoginResponse.Error("No HTTPURLResponse was returned"))
                    }
                }
            }
            task.resume()
        }
    }
    
    func logout(portalUrl: URL,handler: @escaping (_: WatchGuardLogoutResponse) -> Void){
        // Prepare request
        var request = URLRequest(url: URL(string: "\(portalUrl)wgcgi.cgi")!)
        request.timeoutInterval = 3
        request.httpMethod = "POST"
        
        // Body
        request.httpBody = "action=fw_logon&fw_logon_type=logout".data(using: String.Encoding.ascii, allowLossyConversion: false)
        
        // Headers
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue("*/*", forHTTPHeaderField: "Accept")
        request.addValue(WatchGuard.UserAgent, forHTTPHeaderField: "User-Agent")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if error != nil {
                handler(WatchGuardLogoutResponse.Error(error!.localizedDescription.dropSuffix(".")))
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    // A valid response is a redirection to logon.shtml
                    if httpResponse.url?.absoluteString.range(of:"logon.shtml") != nil {
                        
                        // The redirection should have an errcode=502 parameter if the logout was successful
                        if let errcode = URLComponents(string: httpResponse.url!.absoluteString)?.queryItems?.filter({$0.name == "errcode"}).first?.value {
                            if errcode == "502" {
                                handler(WatchGuardLogoutResponse.Success)
                            }else{
                                handler(WatchGuardLogoutResponse.Error(WatchGuard.getErrorCodeStr(errcode)))
                            }
                        }else{
                            os_log("Error on logout. Missing errcode in '%@'",httpResponse.url!.absoluteString)
                            let dataString = String(NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!)
                            handler(WatchGuardLogoutResponse.Error(String(format: "Missing errcode '%@': %@",httpResponse.url!.absoluteString, dataString)))
                        }
                    }else{
                        handler(WatchGuardLogoutResponse.Error(String(format: "Unknown location '%@' (%d)",httpResponse.url!.absoluteString, httpResponse.statusCode)))
                    }
                }else{
                    handler(WatchGuardLogoutResponse.Error("No HTTPURLResponse was returned"))
                }
            }
        }
        task.resume()
    }
        
    class func getErrorCodeStr(_ errcode:String) -> String{
        switch(errcode){
        case "501":
            return "Authentication Failed: Invalid credentials.";
        case "502":
            return "User logged out.";
        case "503":
            return "Your session has expired. Please re-login.";
        case "504":
            return "timeout";
        case "505":
            return "Login Rejected: User reached max login limit.";
        case "506":
            return "Invalid logon type";
        case "507":
            return "Invalid URL";
        case "508":
            return "User is temporarily locked out.";
        case "509":
            return "User is permanently locked out.";
            
        default:
            return String(format: "Invalid error code '%s'", errcode)
        }
    }
}

extension String {
    func dropSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
}
