import Cocoa
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let menuController = MenuController()
    let authManager = AuthManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        authManager.delegate = menuController
        authManager.start()
        
        if DataManager.sharedData.getPortalURL() == nil{
            showPreferences()
        }

        terminateLauncherIfStarted()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        authManager.stop()
    }

    func showPreferences(){
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        let preferencesController = storyboard.instantiateInitialController() as? NSWindowController
        preferencesController!.showWindow(nil)
    }

    func terminateLauncherIfStarted(){
        var startedAtLogin = false
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier == "net.laverse.KeepMeConnectedLauncher" {
                startedAtLogin = true
            }
        }

        // If the app's started, post to the notification center to kill the launcher app
        if startedAtLogin {
            os_log("Killing launcher")
            DistributedNotificationCenter.default().postNotificationName( Notification.Name("NCConstants.KILLME"), object: Bundle.main.bundleIdentifier, userInfo: nil, options: DistributedNotificationCenter.Options.deliverImmediately)
        }else{
            os_log("Launcher is not running")
        }
    }
}
