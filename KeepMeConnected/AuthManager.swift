import Cocoa
import os.log
import SystemConfiguration

enum AuthManagerState : Equatable{
    case Authenticated
    case AuthenticationFailed(_ reason : String)
    case Error(_ reason : String)
    case IncompleteConfiguration
    case NotAuthenticated
    case Uninitialized
}

protocol AuthManagerDelegate {
    func authStateChanged(_ state: AuthManagerState)
}

// AuthManager periodically polls the connectivity status of the user against the portal
// and sends updates to its delegate
class AuthManager: NSObject {
    var delegate : AuthManagerDelegate?
    let watchGuardClient = WatchGuard()
    
    private var timer : Timer?
    
    private var state = AuthManagerState.Uninitialized {
        didSet {
            if oldValue != state{
                self.delegate?.authStateChanged(state)
            }
        }
    }
    
    func start() {
        // Starts a timer that will periodically poll the status on the portal
        if (timer != nil) {return}
        timer = Timer.scheduledTimer(timeInterval: DataManager.sharedData.getPollingInterval(), target: self, selector: #selector(AuthManager.checkStatus), userInfo: nil, repeats: true)
        timer!.fire()
        
        // Watch for MacOS network connectivity change events
        watchConnectivityChanges()
        
        // Listen for another part of the application that might ask to update the status
        NotificationCenter.default.addObserver(forName:Notification.Name("checkStatusTrigger"), object:nil, queue:nil, using:manualCheckTrigger)
    }
    
    func manualCheckTrigger(notification:Notification){
        os_log("A manual check trigger was received")
        timer?.fire()
    }
    
    func watchConnectivityChanges(){
        let callback: SCDynamicStoreCallBack = { (store, flags, info) in
            os_log("Connectivity changed")
            if let info = info {
                let mySelf = Unmanaged<AuthManager>.fromOpaque(info).takeUnretainedValue()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    mySelf.checkStatus()
                }
            }
        }
        var dynamicContext = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        dynamicContext.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        let dcAddress = withUnsafeMutablePointer(to: &dynamicContext, {UnsafeMutablePointer<SCDynamicStoreContext>($0)})
        let store = SCDynamicStoreCreate(kCFAllocatorDefault, Bundle.main.bundleIdentifier! as CFString, callback, dcAddress)
        SCDynamicStoreSetNotificationKeys(store!, ["State:/Network/Global/IPv4"] as CFArray, nil)
        
        let loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, store!, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, CFRunLoopMode.defaultMode)
        CFRunLoopRun()
    }
    
    func stop() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    @objc func checkStatus() {
        // Check the required data are present for a status check
        if let portalUrl = DataManager.sharedData.getPortalURL(){
            os_log("Will try to check the status against the portal")
            watchGuardClient.checkStatus(portalUrl: portalUrl) { response in
                switch(response){
                case .Connected:
                    os_log("Portal says we're authenticated")
                    self.state = AuthManagerState.Authenticated
                case .NotConnected:
                    os_log("Portal says we're not authenticated")
                    self.state = AuthManagerState.NotAuthenticated
                    self.authenticate()
                case .Error(let reason):
                    os_log("Error while checking status: %s",reason)
                    self.state = AuthManagerState.Error(reason)
                }
            }
        }else{
            self.state = AuthManagerState.IncompleteConfiguration
        }
    }
    
    func authenticate(){
        // Check the required data are present for an authentication
        if let portalUrl = DataManager.sharedData.getPortalURL(), let userName = DataManager.sharedData.getUserName(),let password = DataManager.sharedData.getUserPassword(), let userDomain = DataManager.sharedData.getUserDomain(){
            
            os_log("Will try to authenticate against the portal")
            watchGuardClient.logon(portalUrl: portalUrl, userName: userName, userPassword: password,userDomain: userDomain) { response in
                switch(response){
                case .Success:
                    os_log("Authentication successful. Checking status")
                    self.checkStatus()
                case .Failed(let reason):
                    os_log("Failure while login in  the portal: %s",reason)
                    self.state = AuthManagerState.AuthenticationFailed(reason)
                case .Error(let reason):
                    os_log("Error while login in the portal: %s",reason)
                    self.state = AuthManagerState.Error(reason)
                }
            }
        }else{
            self.state = AuthManagerState.IncompleteConfiguration
        }
    }
}
