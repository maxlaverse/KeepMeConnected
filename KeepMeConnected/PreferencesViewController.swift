import Cocoa

enum ResultImage : NSImage.Name {
    case Success = "resultSuccess"
    case Failure = "resultFailure"
}

class PreferencesViewController: NSViewController, NSTextFieldDelegate{
    let watchGuardClient = WatchGuard()
    
    @IBOutlet weak var portalURL: NSTextField!
    @IBOutlet weak var userDomain: NSTextField!
    @IBOutlet weak var userName: NSTextField!
    @IBOutlet weak var userPassword: NSSecureTextField!
    @IBOutlet weak var testResultImage: NSImageView!
    @IBOutlet weak var testSpinner: NSProgressIndicator!
    @IBOutlet weak var testFailureReason: NSTextFieldCell!
    @IBOutlet weak var buttonTestPortalURL: NSButton!
    @IBOutlet weak var buttonTestCredentials: NSButton!

    @objc dynamic var runAtLogin = DataManager.sharedData.getRunAtLogin(){
        didSet {
            DataManager.sharedData.setRunAtLogin(runAtLogin)
        }
    }
    
    @objc dynamic var showNotifications = DataManager.sharedData.shouldShowNotifications(){
        didSet {
            DataManager.sharedData.setShowNotifications(showNotifications)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width,self.view.frame.size.height)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.portalURL?.delegate = self
        self.userName?.delegate = self
        self.userPassword?.delegate = self
        self.userDomain?.delegate = self
        
        loadValues()
        
        self.parent?.view.window?.title = self.title!
    }
    
    override func viewWillDisappear(){
        NotificationCenter.default.post(name: Notification.Name("checkStatusTrigger"), object: nil)
    }
    
    
    func loadValues(){
        if let p = DataManager.sharedData.getPortalURL(){
            self.portalURL?.stringValue = p.absoluteString
        }
        
        if let p = DataManager.sharedData.getUserName(){
            self.userName?.stringValue = p
        }
        
        if let _ = DataManager.sharedData.getUserPassword(){
            self.userPassword?.placeholderString = "--- stored in Keychain ---"
        }

        if let p = DataManager.sharedData.getUserDomain(){
            self.userDomain?.stringValue = p
        }
        updateButtonState()
    }

    func updateButtonState(){
        if let _ = DataManager.sharedData.getPortalURL(){
            self.buttonTestPortalURL?.isEnabled = true
        }else{
            self.buttonTestPortalURL?.isEnabled = false
        }

        if let _ = DataManager.sharedData.getUserName(),let _ = DataManager.sharedData.getUserPassword(), let _ = DataManager.sharedData.getUserDomain(){
            self.buttonTestCredentials?.isEnabled = true
        }else{
            self.buttonTestCredentials?.isEnabled = false
        }
    }
    
    func controlTextDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            if textField == self.portalURL{
                if DataManager.sharedData.setPortalURL(textField.stringValue){
                    textField.textColor = NSColor.textColor
                }else{
                    textField.textColor = NSColor.red
                }
            }
            if textField == self.userName{
                if DataManager.sharedData.setUserName(textField.stringValue){
                    textField.textColor = NSColor.textColor
                }else{
                    textField.textColor = NSColor.red
                }
            }
            if textField == self.userDomain{
                if DataManager.sharedData.setUserDomain(textField.stringValue){
                    textField.textColor = NSColor.black
                }else{
                    textField.textColor = NSColor.red
                }
            }
            if textField == self.userPassword{
                DataManager.sharedData.setUserPassword(textField.stringValue)
            }
            updateButtonState()
        }
    }
    
    @IBAction func buttonTestPortalURL(_ sender: NSButton) {
        displayTestStart(sender)
        watchGuardClient.checkStatus(portalUrl: DataManager.sharedData.getPortalURL()!) { response in
            DispatchQueue.main.async {
                switch(response){
                case .Connected, .NotConnected:
                    self.displayTestResult(image: ResultImage.Success)
                case .Error(let reason):
                    self.displayTestResult(image: ResultImage.Failure, title: reason)
                }
            }
        }
    }
    
    @IBAction func buttonTestCredentials(_ sender: Any) {
        displayTestStart(sender)

        // Check if we are already connected
        self.watchGuardClient.checkStatus(portalUrl: DataManager.sharedData.getPortalURL()!) { response in
            DispatchQueue.main.async {
                switch(response){
                case .Connected:

                    // We are already connected, first logout
                    let answer = self.dialogContinue(question: "You are already authenticated", text: "To test your credentials, we will need to log you out first.")
                    if answer {
                        self.watchGuardClient.logout(portalUrl: DataManager.sharedData.getPortalURL()!) { response in
                            switch(response){
                            case .Success:
                                // And then try the credentials
                                self.testLogon()
                            case .Error(let reason), .Failed(let reason):
                                DispatchQueue.main.async {
                                    self.displayTestResult(image: ResultImage.Failure, title: reason)
                                }
                            }
                        }
                    }else{
                        self.displayTestResult(image: ResultImage.Failure, title: "Test aborted")
                    }
                case .NotConnected:
                    // We are not connected. Try the credentials
                    self.testLogon()
                case .Error(let reason):
                    self.displayTestResult(image: ResultImage.Failure, title: reason)
                }
            }
        }
    }
    
    func testLogon(){
        // Check if the firewall is just accepting any credentials because the way the user is connected (e.g already authenticated through VPN)
        watchGuardClient.logon(portalUrl: DataManager.sharedData.getPortalURL()!, userName: "crap@crap", userPassword: DataManager.sharedData.getUserPassword()!, userDomain: DataManager.sharedData.getUserDomain()!) { response in
            DispatchQueue.main.async {
                switch(response){
                case .Success:
                    self.displayTestResult(image: ResultImage.Failure, title: "The portal is blindly accepting any credentials.")
                case .Error(_), .Failed(_):
                    self.watchGuardClient.logon(portalUrl: DataManager.sharedData.getPortalURL()!, userName: DataManager.sharedData.getUserName()!, userPassword: DataManager.sharedData.getUserPassword()!,userDomain: DataManager.sharedData.getUserDomain()!) { response in
                        DispatchQueue.main.async {
                            switch(response){
                            case .Success:
                                self.displayTestResult(image: ResultImage.Success)
                            case .Error(let reason), .Failed(let reason):
                                self.displayTestResult(image: ResultImage.Failure, title: reason)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func buttonResetSettings(_ sender: Any) {
        DataManager.sharedData.reset()
        NSApplication.shared.terminate(nil)
    }
    
    func displayTestStart(_ sender: Any){
        testSpinner.startAnimation(sender)
        testSpinner.isHidden = false
        testResultImage.isHidden = true
        testFailureReason.title = ""
    }
    
    func displayTestResult(image : ResultImage, title : String? = nil){
        testFailureReason.title = title ?? ""
        testResultImage.image = NSImage(named:image.rawValue)
        testSpinner.isHidden = true
        testResultImage.isHidden = false
        testSpinner.stopAnimation(nil)
    }
    
    func dialogContinue(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
