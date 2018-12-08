import Cocoa
import os.log

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let mainAppIdentifier = Bundle.main.bundleIdentifier!.replacingOccurrences(of: "Helper", with: "")

        guard NSRunningApplication.runningApplications(withBundleIdentifier: mainAppIdentifier).isEmpty else {
            NSApp.terminate(nil)
            return
        }

        let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents
        let mainPath = NSString.path(withComponents: Array(pathComponents[0...(pathComponents.count - 5)]))
        os_log("Will start %s",mainPath)
        NSWorkspace.shared.launchApplication(mainPath)
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

