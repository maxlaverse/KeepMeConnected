## KeepMeConnected

Always stay connected on your Watchguard Portal.

This application polls your status on the Watchguard Portal periodically and re-authenticates you if you're logged out.
It also detects when your connectivity changes to avoid being unauthenticated for too long when switching from Ethernet to Wifi.
Your password is stored in the MacOS Keychain.

## Installation
Compile the application yourself, or download the binary on the [release page](https://github.com/maxlaverse/KeepMeConnected/releases).

## Debugging
Use the `Console` (`Applications > Utilities > Console`) and filter by process (`KeepMeConnected`) to get more information about
what the application is doing.
