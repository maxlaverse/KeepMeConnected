import Cocoa

class WizardViewControlle2: NSViewController, NSTextFieldDelegate{
    let authManager = AuthManager()

    @IBOutlet weak var buttonCancel: NSButton!
    @IBOutlet weak var buttonTest: NSButton!
    @IBOutlet weak var portalURLValidationImage: NSImageView!
    @IBOutlet weak var portalURL: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        authManager.delegate = self
        self.preferredContentSize = NSMakeSize(self.view.frame.size.width,self.view.frame.size.height)
    }

    @IBAction func buttonTest(_ sender: Any) {
        if !DataManager.sharedData.setPortalURL(self.portalURL.stringValue){
            self.portalURLValidationImage.image = NSImage(named:NSImage.Name("cancel"))
            return
        }
        authManager.checkStatus()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        self.portalURL?.delegate = self
    }
}

extension WizardViewControlle2 : AuthManagerDelegate {
    func authStateChanged(_ state: AuthManagerState) {
        var image = NSImage.Name("cancel")
        switch state {
        case AuthManagerState.notAuthenticated:
            image = NSImage.Name("checked")
        case AuthManagerState.authenticated:
            image = NSImage.Name("checked")
        default:
            image = NSImage.Name("cancel")
        }
        DispatchQueue.main.async {
            self.portalURLValidationImage.image = NSImage(named:image)
        }
    }
}
