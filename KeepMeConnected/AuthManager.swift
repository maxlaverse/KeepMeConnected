import Cocoa
import os.log
import SystemConfiguration

enum AuthManagerState : Equatable{
    case Authenticated
    case AuthenticationFailed(_ reason : String)
    case Error(_ reason : String)
    case IncompleteConfiguration
    case NotAuthenticated
    case Unknown(_ reason : String)
}

protocol AuthManagerDelegate {
    func authStateChanged(_ state: AuthManagerState)
}

// AuthManager periodically polls the connectivity status of the user against the portal
// and sends updates to its delegate
class AuthManager: NSObject {
    var delegate : AuthManagerDelegate?

    private let connectivityService = ConnectivityService()
    private let watchGuardClient = WatchGuard()
    private var newSettingsObserver: Any? = nil
    private var timer : Timer?

    private var state = AuthManagerState.Unknown("initializing") {
        didSet {
            if oldValue != state{
                self.delegate?.authStateChanged(state)
            }
        }
    }

    override init(){
        super.init()
        connectivityService.delegate = self
    }

    func start() {
        if let portalUrl = DataManager.sharedData.getPortalURL(){
            // Watch for MacOS network connectivity change events
            connectivityService.watch(portalUrl.host!)
        }

        // Listen for configuration changes
        newSettingsObserver = NotificationCenter.default.addObserver(forName:Notification.Name("KeepMeConnected.NewSettings"), object:nil, queue:nil, using:applyNewSettings)
    }

    func stop() {
        if let settingsObserver = newSettingsObserver{
            NotificationCenter.default.removeObserver(settingsObserver)
            newSettingsObserver = nil
        }

        stopPolling()
        connectivityService.stopWatching()
    }

    private func pollPeriodically(){
        if (timer == nil) {
            timer = Timer.scheduledTimer(timeInterval: DataManager.sharedData.getPollingInterval(), target: self, selector: #selector(AuthManager.checkStatus), userInfo: nil, repeats: true)
        }

        timer!.fire()
    }

    private func stopPolling(){
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    private func applyNewSettings(notification:Notification){
        os_log("Applying new settings")
        if let portalUrl = DataManager.sharedData.getPortalURL(){
            DispatchQueue.main.async {
                self.connectivityService.watch(portalUrl.host!)
            }
        }
    }
    
    @objc private func checkStatus() {
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
    
   private func authenticate(){
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

extension AuthManager : ConnectivityServiceDelegate {
    func connectivityChanged(_ reachability: ConnectivityChanged){
        DispatchQueue.main.async {
            switch reachability {
            case .Reachable:
                self.pollPeriodically()
            case .ReachableWithNewAddress:
                self.pollPeriodically()
            case .Unreachable:
                self.stopPolling()
                self.state = AuthManagerState.Unknown("Portal is unreachable")
            }
        }
    }
}
