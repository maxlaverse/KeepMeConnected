import Foundation
import SystemConfiguration
import os.log

enum ConnectivityChanged : Equatable{
    case ReachableWithNewAddress
    case Reachable
    case Unreachable
}

protocol ConnectivityServiceDelegate {
    func connectivityChanged(_ reachability: ConnectivityChanged)
}

class ConnectivityService: NSObject {
    var delegate : ConnectivityServiceDelegate?

    private var currentReachabilityFlags: SCNetworkReachabilityFlags?
    private var reachability: SCNetworkReachability?
    private var loop : CFRunLoopSource?

    func watch(_ hostname: String) {
        stopWatching()

        // Watch reachability of the portal
        watchReachabilityChanges(hostname)

        // Watch the network to detect IP changes
        watchConnectivityChanges()
    }

    func stopWatching() {
        if let reachability = reachability{
            SCNetworkReachabilitySetCallback(reachability, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachability, nil)
            self.reachability = nil
        }
        if let loop = loop{
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), loop, CFRunLoopMode.defaultMode)
            CFRunLoopStop(CFRunLoopGetCurrent())
            self.loop = nil
        }
    }

    private func watchReachabilityChanges(_ hostname: String){
        let callback: SCNetworkReachabilityCallBack? = { (_, flags, info) in
            guard let info = info else { return }

            let handler = Unmanaged<ConnectivityService>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async {
                handler.checkReachability(flags: flags)
            }
        }

        reachability = SCNetworkReachabilityCreateWithName(nil, hostname)!

        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<ConnectivityService>.passUnretained(self).toOpaque())

        // Registers the callback. `callbackClosure` is the closure where we manage the callback implementation
        if !SCNetworkReachabilitySetCallback(reachability!, callback, &context) {
            // Not able to set the callback
        }

        // Sets the dispatch queue which is `DispatchQueue.main` for this example. It can be also a background queue
        if !SCNetworkReachabilitySetDispatchQueue(reachability!, DispatchQueue.main) {
            // Not able to set the queue
        }

        // Runs the first time to set the current flags
        DispatchQueue.main.async {
            self.currentReachabilityFlags = nil

            var flags = SCNetworkReachabilityFlags()
            SCNetworkReachabilityGetFlags(self.reachability!, &flags)

            self.checkReachability(flags: flags)
        }
    }

    private func watchConnectivityChanges(){
        let callback: SCDynamicStoreCallBack = { (store, _, info) in
            guard let info = info else { return }

            let handler = Unmanaged<ConnectivityService>.fromOpaque(info).takeUnretainedValue()
             DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                handler.checkConnectivity()
            }
        }

        var context = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let dcAddress = withUnsafeMutablePointer(to: &context, {UnsafeMutablePointer<SCDynamicStoreContext>($0)})
        let store = SCDynamicStoreCreate(kCFAllocatorDefault, Bundle.main.bundleIdentifier! as CFString, callback, dcAddress)
        SCDynamicStoreSetNotificationKeys(store!, ["State:/Network/Global/IPv4"] as CFArray, nil)

        loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, store!, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, CFRunLoopMode.defaultMode)
        CFRunLoopRun()
    }

    private func checkConnectivity(){
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability!, &flags)

        if currentReachabilityFlags == flags && isNetworkReachable(with: flags) {
            os_log("The portal is reachable with a new IP")
            self.delegate?.connectivityChanged(ConnectivityChanged.ReachableWithNewAddress)
        }
    }

    private func checkReachability(flags: SCNetworkReachabilityFlags) {
        if currentReachabilityFlags != flags {
            if isNetworkReachable(with: flags){
                os_log("The portal is reachable")
                self.delegate?.connectivityChanged(ConnectivityChanged.Reachable)
            }else{
                os_log("The portal is not reachable")
                self.delegate?.connectivityChanged(ConnectivityChanged.Unreachable)
            }
            currentReachabilityFlags = flags
        }
    }

    private func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)

        return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
    }
}
