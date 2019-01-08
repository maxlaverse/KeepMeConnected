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
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        authManager.stop()
    }

    func showPreferences(){
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
        let preferencesController = storyboard.instantiateInitialController() as? NSWindowController
        preferencesController!.showWindow(nil)
    }
}
