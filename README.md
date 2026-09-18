<p align="center">
<img width="500" height="500" alt="packagespoofer_icn_512x512-removebg-preview" src="https://github.com/user-attachments/assets/1414280b-3ede-41be-aa02-d2c9b619212e" />
</p>

# packageSpoofer
packageSpoofer allows you to edit an application's `CFBundleIdentifier` and resign it to force it to run regardless of a provision profile restricting the app from opening.

# How it works
packageSpoofer uses `plutil` to modify the contents of the app's `Info.plist` to change the app's `CFBundleIdentifier`, as most provision profiles use the app's package name to block it from opening. Then once the package name is changed, we use `codesign` to resign the app with the new package name to allow macOS to launch the app.

# Features
- **Bundle ID spoofing**: Changes app's reported bundle ID to bypass app blocks
- **App category spoofing**: Changes app's App Store category ID to make apps even more undetectable to blocks
- **[appUnblocker](https://github.com/yourworstnightmare1/appunblocker) integration**: Force opens apps that have unsigned developer IDs/local signatures using folder manipulation
- **Embedded Shell**: Use the CLI version without Terminal by using the Embedded Shell, which runs a shell inside of an app
- **Make Executable**: Fix apps crashing on launch by applying chmod to fix executable files
- **Bypass Gatekeeper**: Applies gatekeeper bypass on app to allow it to open even if reported as unsafe
- **Hide File After Signing**: Hides app after packageSpoofer finishes all patches
- **Bundle ID generation**: Randomly generate bundle IDs following proper macOS bundle ID conventions with one click
- **Force Metal HUD on app**: Makes app open with the Metal HUD, with system and performance info (won't work on all apps)



# Compatibility
packageSpoofer GUI edition is able to run on devices with **macOS 14.6 or newer**. The CLI edition can run on devices with **macOS 10.13 or newer and requires an xterm-compatible terminal**.

### Note about App Store apps
It is impossible to sign applications installed from the App Store without an Xcode identity, which is not possible without Xcode (which requires admin), and installing it will likely not be possible for the target audience of this tool. Most App Store apps are DRM protected (even the free apps) and all App Store apps are all cryptographically locked, using a sealed code directory and hardened by macOS System Integrity Protection (SIP). Basically you're never signing App Store apps with a local signature, at least without Xcode. There will be no plans to support App Store apps or any plans to try to circumvent DRM or other security measures by Apple or third-parties.

## Note about apps installed externally
When downloading a file from AirDrop or another website or server, the app will likely lose its execution ability when it is installed, making it crash when trying to launch/showing an "access denied" message in the command line. To fix this, make sure to enable "Apply binary patches" in the app. If you need to manually do this, run `chmod +x` on your app executable (ex: `chmod +x ~/Downloads/Steam.app/Contents/MacOS/Steam`).
