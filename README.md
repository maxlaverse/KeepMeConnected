## KeepMeConnected

Always stay connected on the Watchguard Authentication Portal of your company.

KeepMeConnected polls your status on the Watchguard Authentication Portal periodically and re-authenticates if you're logged out.
It also detects when your connectivity changes to avoid being unauthenticated for too long when switching from Ethernet to Wifi.
Your password is stored in the MacOS Keychain and the icon in the status bar allows you to keep an eye on your authentication status.

## Installation
Compile the application yourself

Or:
* download the binary on the [release page](https://github.com/maxlaverse/KeepMeConnected/releases)
* move it into your application folder, right click on the icon and then click on `Open`
* acknowledge the security warning displayed because the application is distributed outside the AppStore

## Debugging
Use the `Console` (`Applications > Utilities > Console`) and filter by process (`KeepMeConnected`) to get more information about
what the application is doing.

## Disclaimer

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
