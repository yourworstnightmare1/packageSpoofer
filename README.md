<p align="center">
<img width="500" height="500" alt="packagespoofer_icn_512x512-removebg-preview" src="https://github.com/user-attachments/assets/1414280b-3ede-41be-aa02-d2c9b619212e" />
</p>

# packageSpoofer
packageSpoofer allows you to edit an application's `CFBundleIdentifier` and resign it to force it to run regardless of a provision profile restricting the app from opening.

# How it works
packageSpoofer uses `plutil` to modify the contents of the app's `Info.plist` to change the app's `CFBundleIdentifier`, as most provision profiles use the app's package name to block it from opening. Then once the package name is changed, we use `codesign` to resign the app with the new package name to allow macOS to launch the app.

# Features
- Already implemented:
- [x] Bundle with appUnblocker (before running packageSpoofer, appUnblocker will be used to bypass unknown developer setting)
- [x] Fix binary crash (runs chmod on app before running to make sure app launches)
- [x] Automatically hide the file from appearing in Finder (only available through Finder search)
- to be implemented later on:
- [ ] Sign apps with Apple Developer ID (Requires network connection)
- [ ] Generate package IDs every time the app is run (random 4/8/12 byte generated developer/app name string)

# Compilation
Compile using the `default.sh` script in the root of packageSpoofer's folder, and run it in a terminal using chmod:\
\
`chmod +x default.sh`\
\
`chmod` allows macOS to execute the file.

# Compatibility
packageSpoofer is able to run on macOS 12+ with an xterm-compatible terminal with shellscript installed. It may run on older versions, but they are untested.
