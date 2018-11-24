import Cocoa
import os.log

enum StatusImage : NSImage.Name {
    case Connected = "statusConnected"
    case NotConnected = "statusNotConnected"
}

class MenuController : NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    var preferencesController : NSWindowController?
    var aboutController : NSWindowController?
    
    override init() {
        super.init()
        setUpMenu()
    }
    
    func setUpMenu(){
        let menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "Status: Initializing", action: nil, keyEquivalent: "")
        statusMenuItem.tag=1
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let aboutMenuItem = NSMenuItem(title: "About KeepMeConnected", action: #selector(MenuController.about(_:)), keyEquivalent: "")
        aboutMenuItem.target=self
        menu.addItem(aboutMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let preferencesMenuItem = NSMenuItem(title:"Preferences...", action: #selector(MenuController.preferences), keyEquivalent: ",")
        preferencesMenuItem.target=self
        menu.addItem(preferencesMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit KeepMeConnected", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q"))
        
        statusItem.menu = menu
        statusItem.button!.image = NSImage(named:NSImage.Name(StatusImage.NotConnected.rawValue))
    }
    
    @objc  func preferences(_ sender: Any?) {
        if !(preferencesController != nil){
            let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
            preferencesController = storyboard.instantiateInitialController() as? NSWindowController
        }
        
        if (preferencesController != nil){
            preferencesController!.showWindow(sender)
        }
        
        // Force the window to stay on the background even if the KeyChain popups appear
        NSApp.activate(ignoringOtherApps:true)
    }
    
    @objc  func about(_ sender: Any?) {
        let appVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String
        
        let msg = NSAlert()
        msg.addButton(withTitle:"OK")
        msg.messageText = "About"
        msg.informativeText = "Icons made by Freepik and Maxim Basinski from www.flaticon.com\n\nVersion \(appVersion!)"
        msg.alertStyle = NSAlert.Style.informational
        msg.runModal()
    }
    
    func displayNotificationWithText(_ text : String) {
        let notification = NSUserNotification()
        notification.title = "KeepMeConnected"
        notification.informativeText = text
        notification.soundName = nil
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func updateStatus(message: String, image : StatusImage){
        self.statusItem.menu?.item(withTag: 1)?.title = "Status: \(message)"
        self.statusItem.button!.image = NSImage(named:NSImage.Name(image.rawValue))
        
        if DataManager.sharedData.shouldShowNotifications(){
            displayNotificationWithText(message)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension MenuController : AuthManagerDelegate {
    func authStateChanged(_ state: AuthManagerState) {
        DispatchQueue.main.async {
            switch state {
            case AuthManagerState.NotAuthenticated:
                self.updateStatus(message: "Not authenticated",image:StatusImage.NotConnected)
            case AuthManagerState.Authenticated:
                self.updateStatus(message: "Authenticated",image:StatusImage.Connected)
            case AuthManagerState.AuthenticationFailed(let reason):
                self.updateStatus(message: String(format: "Authentication failed (%@)",reason),image:StatusImage.NotConnected)
            case AuthManagerState.IncompleteConfiguration:
                self.updateStatus(message: "Incomplete configuration",image:StatusImage.NotConnected)
            case AuthManagerState.Uninitialized:
                self.updateStatus(message: "Waiting for the first check",image:StatusImage.NotConnected)
            case AuthManagerState.Error(let reason):
                self.updateStatus(message: String(format: "Error (%@)",reason),image:StatusImage.NotConnected)
            }
        }
    }
}
