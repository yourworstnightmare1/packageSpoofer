<p align="center">
<img width="500" height="500" alt="packagespoofer_icn_512x512-removebg-preview" src="https://github.com/user-attachments/assets/1414280b-3ede-41be-aa02-d2c9b619212e" />
</p>

# packageSpoofer
packageSpoofer allows you to edit an application's `CFBundleIdentifier` and resign it to force it to run regardless of a provision profile restricting the app from opening.

# How it works
packageSpoofer uses `plutil` to modify the contents of the app's `Info.plist` to change the app's `CFBundleIdentifier`, as most provision profiles use the app's package name to block it from opening. Then once the package name is changed, we use `codesign` to resign the app with the new package name to allow macOS to launch the app.

# Features
- Automatically make apps executable with the "Apply binary fix" patch
- Remove frameworks through the app (Beta)
- Change bundle IDs anytime

# Compatibility
packageSpoofer GUI edition is able to run on devices with **macOS 14.6 or newer**. The CLI edition can run on devices with **macOS 10.13 or newer and requires an xterm-compatible terminal**.
