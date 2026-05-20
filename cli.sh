#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'
# To apply colors use echo -e
# Make sure to remove colors with ${NC}

clear
# Selection


 read -p "Enter the directory of your app: " name
 name="${name%\"}"; name="${name#\"}"
 name="${name%\'}"; name="${name#\'}"
 name="${name%/}"
 name="$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
 if [[ "$name" == */Contents/Info.plist ]]; then
    name="$(dirname "$(dirname "$name")")"
 fi

 read -p "Enter the new package identifier (it can be random characters, has to start with com.) (e.g., com.example.app): " identifier
 echo "Pre-Patch Scripts:"
 read -p "(Not required) Would you like to apply framework patches? (May break some apps) [y/n]: " frameworkChoice
 read -p "(Not required) Would you like to apply binary patches? (fixes crashes with some apps) [y/n]: " patchChoice
 echo "Post-Patch Scripts:"
 read -p "(Not required) Would you like to apply appUnblocker? (Wraps the app in a new .app bundle and adds a launch shortcut symlink beside it.) [y/n]: " appUnblockerChoice
 read -p "(Not required) Would you like to hide the file after signing? (Marks the app (and launch shortcut, if created) as hidden in Finder after signing.) [y/n]: " hideFileAfterSigningChoice
 echo ""

 if [ -z "$name" ] || [ -z "$identifier" ]; then
     echo -e "${RED}Error: App directory and package identifier are required.${NC}"
     read -p "Press any key to restart..."
     exit 1
 fi
 if [ "$patchChoice" == "y" ] || [ "$patchChoice" == "Y" ]; then
     echo -e "${GREEN}Binary patch will be applied.${NC}"
 else
     echo -e "${YELLOW}Binary patch will not be applied.${NC}"
    fi
if [ "$frameworkChoice" == "y" ] || [ "$frameworkChoice" == "Y" ]; then
     echo -e "${GREEN}Framework patch will be applied.${NC}"
 else
     echo -e "${YELLOW}Framework patch will not be applied.${NC}"
 fi
 if [ "$appUnblockerChoice" == "y" ] || [ "$appUnblockerChoice" == "Y" ]; then
     echo -e "${GREEN}AppUnblocker will be applied.${NC}"
 else
     echo -e "${YELLOW}AppUnblocker will not be applied.${NC}"
 fi
 if [ "$hideFileAfterSigningChoice" == "y" ] || [ "$hideFileAfterSigningChoice" == "Y" ]; then
     echo -e "${GREEN}Hide File After Signing will be applied.${NC}"
 else
     echo -e "${YELLOW}Hide File After Signing will not be applied.${NC}"
 fi
 echo ""
echo "Processing..."
clear

app_name="$(basename "$name")"
app_base="${app_name%.app}"
parent_dir="$(dirname "$name")"

if [ -f "$name/$app_name/Contents/Info.plist" ]; then
    is_wrapped=1
    wrapper_path="$name"
    patch_app="$name/$app_name"
else
    is_wrapped=0
    wrapper_path=""
    patch_app="$name"
fi
pname="$patch_app/Contents/Info.plist"

echo "Your choices:"
echo "App Directory: $name"
if [ "$is_wrapped" -eq 1 ]; then
    echo -e "${YELLOW}Detected existing appUnblocker wrapper. Patching nested app: $patch_app${NC}"
fi
echo "Property List: $pname"
echo "New Package Identifier: $identifier"
echo "Apply Framework Patch: $frameworkChoice"
echo "Apply Binary Patch: $patchChoice"
echo "Apply AppUnblocker: $appUnblockerChoice"
echo "Hide File After Signing: $hideFileAfterSigningChoice"
echo ""
echo -e "${BOLD}Custom plist directories will be available in the next version of packageSpoofer, give it some time...${NC}"
read -p "Press any key to confirm and proceed..." -n1 -s

#####################
### Exploit Begin ###
#####################

# Bundle ID modification
echo ""
echo -e "${BOLD}Starting...${NC}"
echo -e "///////////////////////////////////"
echo -e "//////  packageSpoofer 2.0   //////"
echo -e "//////      Developed by     //////"
echo -e "//////  yourworstnightmare1  //////"
echo -e "///////////////////////////////////"

if [ ! -d "$name" ]; then
    echo -e "${RED}Error: App bundle not found at $name${NC}"
    read -p "Press any key to exit..."
    exit 1
fi

volume_path=$(df "$name" | awk 'NR==2 {print $NF}')
volume_name=$(basename "$volume_path")
if mount | grep " on ${volume_path} " | grep -q "read-only"; then
    echo -e "${RED}This is a read-only volume. packageSpoofer cannot use this volume.${NC}"
    echo ""
    echo "If you are trying to install an app from a .dmg file, move the app from the .dmg to any location on your system, then click \"Browse...\" in the app and select the app."
    echo ""
    read -p "Press any key to exit..."
    exit 1
fi

write_test_file="$patch_app/Contents/.packagespoofer_write_test"
if ! touch "$write_test_file" 2>/dev/null; then
    echo -e "${RED}Error: The app is not writable at $name${NC}"
    echo -e "${YELLOW}Copy the app to a writable folder (for example ~/Downloads) and try again.${NC}"
    echo -e "${YELLOW}Example: cp -R \"$name\" ~/Downloads/${NC}"
    read -p "Press any key to exit..."
    exit 1
fi
rm -f "$write_test_file"
echo -e "${GREEN}App location is writable.${NC}"

# Pre-patch (before bundle ID change and signing)
if [ "$frameworkChoice" == "y" ] || [ "$frameworkChoice" == "Y" ]; then
    echo -e "${BOLD}[Pre-Patch] Removing embedded frameworks...${NC}"
  frameworksPath="$patch_app/Contents/Frameworks"
  if [ -d "$frameworksPath" ]; then
      echo -e "${YELLOW}rm -rf $frameworksPath${NC}"
      rm -rf "$frameworksPath"
      if [ $? -ne 0 ]; then
          echo -e "${RED}Error: Failed to remove frameworks.${NC}"
          read -p "Press any key to exit..."
          exit 1
      fi
      echo -e "${GREEN}Frameworks removed successfully.${NC}"
  else
      echo -e "${YELLOW}No embedded Frameworks folder found; skipping.${NC}"
  fi
fi
if [ "$patchChoice" == "y" ] || [ "$patchChoice" == "Y" ]; then
    echo -e "${BOLD}[Pre-Patch] Applying binary fix...${NC}"
    echo -e "${YELLOW}chmod: add execute permission: $patch_app/Contents/MacOS/*${NC}"
    chmod +x "$patch_app"/Contents/MacOS/* 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to set executable permissions.${NC}"
        read -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}Binary fix applied successfully.${NC}"
fi

echo "Editing Info.plist..."
echo -e "${YELLOW}Edit $pname: replace CFBundleIdentifier: string="$identifier"${NC}"
plutil -replace CFBundleIdentifier -string "$identifier" "$pname"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to edit Info.plist: It is missing or corrupt.${NC}"
    read -p "Press any key to exit..."
    exit 1
fi
echo -e "${GREEN}Info.plist edited successfully.${NC}"

# Signing process
echo -e "${BOLD}Signing application...${NC}"
echo -e "${YELLOW}codesign: Signing application using ad-hoc signature: $patch_app${NC}"
codesign --force --deep --sign - "$patch_app"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Code signing failed: The file may be corrupt or in a protected directory.${NC}"
    echo -e "${YELLOW}If you recieved the error "bundle format is ambiguous could be app or framework", the signing succeeded but there may be additional issues (likely does not affect the function of the app).${NC}"
    read -p "Press any key to exit..."
    exit 1
fi
echo -e "${GREEN}Application signed successfully.${NC}"

# Post-patch (after signing)
if [ "$appUnblockerChoice" == "y" ] || [ "$appUnblockerChoice" == "Y" ]; then
    echo -e "${BOLD}[Post-Patch] Applying appUnblocker...${NC}"

    if [ "$is_wrapped" -eq 1 ]; then
        echo -e "${YELLOW}appUnblocker: Wrapper already exists; refreshing launch shortcut only.${NC}"
        nested_app="$patch_app"
        wrapper_path="$name"
    else
        echo -e "${YELLOW}appUnblocker: Creating folder at $parent_dir/appUnblocker-$(uuidgen)${NC}"
        temp_dir="$parent_dir/appUnblocker-$(uuidgen)"
        mkdir "$temp_dir" || { echo -e "${RED}Error: Failed to create appUnblocker folder.${NC}"; read -p "Press any key to exit..."; exit 1; }

        echo -e "${YELLOW}appUnblocker: Moving app into wrapper...${NC}"
        mv "$patch_app" "$temp_dir/$app_name" || { rm -rf "$temp_dir"; echo -e "${RED}Error: Failed to move app into wrapper.${NC}"; read -p "Press any key to exit..."; exit 1; }
        mv "$temp_dir" "$name" || { echo -e "${RED}Error: Failed to finalize wrapper.${NC}"; read -p "Press any key to exit..."; exit 1; }

        nested_app="$name/$app_name"
        wrapper_path="$name"
        patch_app="$nested_app"
        is_wrapped=1
        echo -e "${GREEN}Created wrapper at $wrapper_path${NC}"
    fi

    display_name="$app_base"
    if [ -f "$nested_app/Contents/Info.plist" ]; then
        plist_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$nested_app/Contents/Info.plist" 2>/dev/null) \
            || plist_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$nested_app/Contents/Info.plist" 2>/dev/null)
        if [ -n "$plist_name" ]; then
            display_name="$plist_name"
        fi
    fi
    shortcut_name="Launch ${display_name}.app"
    shortcut_path="$parent_dir/$shortcut_name"
    echo -e "${YELLOW}appUnblocker: Creating launch shortcut at $shortcut_path${NC}"
    rm -f "$shortcut_path"
    ln -sf "$nested_app" "$shortcut_path"
    if [ -L "$shortcut_path" ]; then
        echo -e "${GREEN}Launch shortcut created at $shortcut_path${NC}"
    else
        echo -e "${RED}Error: Failed to create launch shortcut.${NC}"
        read -p "Press any key to exit..."
        exit 1
    fi

    echo -e "${YELLOW}codesign: Re-signing nested app after appUnblocker...${NC}"
    codesign --force --deep --sign - "$nested_app"
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}WARN: Could not re-sign nested app (the app may still run).${NC}"
    else
        echo -e "${GREEN}Nested app signed successfully.${NC}"
    fi
fi
if [ "$hideFileAfterSigningChoice" == "y" ] || [ "$hideFileAfterSigningChoice" == "Y" ]; then
    echo -e "${BOLD}[Post-Patch] Hiding file in Finder...${NC}"
    chflags hidden "$name"
    for shortcut in "$parent_dir"/Launch\ *.app; do
        if [ -e "$shortcut" ]; then
            chflags hidden "$shortcut"
        fi
    done
    echo -e "${GREEN}Hidden app (and launch shortcut, if present) in Finder.${NC}"
fi

# Integrity checks (after all post-patch steps)
echo ""
echo -e "${BOLD}Checking file integrity...${NC}"
integrity_failures=0

integrity_app="$patch_app"

if [ -d "$integrity_app" ]; then
    echo -e "${GREEN}PASS: App bundle exists at $integrity_app${NC}"
else
    echo -e "${RED}FAIL: App bundle is missing at $integrity_app${NC}"
    integrity_failures=$((integrity_failures + 1))
fi

if [ -f "$integrity_app/Contents/Info.plist" ]; then
    if plutil -lint "$integrity_app/Contents/Info.plist" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS: Info.plist is present and valid.${NC}"
    else
        echo -e "${RED}FAIL: Info.plist is corrupt or unreadable.${NC}"
        integrity_failures=$((integrity_failures + 1))
    fi
else
    echo -e "${RED}FAIL: Info.plist is missing.${NC}"
    integrity_failures=$((integrity_failures + 1))
fi

actual_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$integrity_app/Contents/Info.plist" 2>/dev/null)
if [ "$actual_bundle_id" == "$identifier" ]; then
    echo -e "${GREEN}PASS: Bundle ID matches ($identifier).${NC}"
else
    echo -e "${RED}FAIL: Bundle ID mismatch (expected $identifier, found ${actual_bundle_id:-none}).${NC}"
    integrity_failures=$((integrity_failures + 1))
fi

macos_dir="$integrity_app/Contents/MacOS"
if [ -d "$macos_dir" ]; then
    executable_found=0
    executable_executable=0
    for executable in "$macos_dir"/*; do
        if [ -f "$executable" ] && [ ! -L "$executable" ]; then
            executable_found=1
            if [ -x "$executable" ]; then
                executable_executable=1
                echo -e "${GREEN}PASS: Main executable is present and executable ($(basename "$executable")).${NC}"
                break
            fi
        fi
    done
    if [ "$executable_found" -eq 0 ]; then
        echo -e "${RED}FAIL: No main executable found in Contents/MacOS.${NC}"
        integrity_failures=$((integrity_failures + 1))
    elif [ "$executable_executable" -eq 0 ]; then
        echo -e "${RED}FAIL: Main executable is not marked executable.${NC}"
        integrity_failures=$((integrity_failures + 1))
    fi
else
    echo -e "${RED}FAIL: Contents/MacOS directory is missing.${NC}"
    integrity_failures=$((integrity_failures + 1))
fi

sign_target="$integrity_app"
if [ "$is_wrapped" -eq 1 ]; then
    echo -e "${YELLOW}NOTE: Verifying signature on nested app ($sign_target). The outer wrapper ($wrapper_path) is not a signed bundle.${NC}"
fi
if codesign --verify --deep --strict "$sign_target" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS: Code signature verifies for $sign_target${NC}"
elif codesign --verify --deep "$sign_target" >/dev/null 2>&1; then
    echo -e "${YELLOW}WARN: Strict signature check failed, but deep verification passed for $sign_target (common with ad-hoc signing).${NC}"
else
    echo -e "${RED}FAIL: Code signature verification failed for $sign_target${NC}"
    integrity_failures=$((integrity_failures + 1))
fi

if [ "$is_wrapped" -eq 1 ]; then
    display_name="$app_base"
    if [ -f "$integrity_app/Contents/Info.plist" ]; then
        plist_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$integrity_app/Contents/Info.plist" 2>/dev/null) \
            || plist_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$integrity_app/Contents/Info.plist" 2>/dev/null)
        if [ -n "$plist_name" ]; then
            display_name="$plist_name"
        fi
    fi
    shortcut_path="$parent_dir/Launch ${display_name}.app"
    if [ -d "$wrapper_path/$app_name" ]; then
        echo -e "${GREEN}PASS: appUnblocker wrapper contains nested app ($app_name).${NC}"
    else
        echo -e "${RED}FAIL: appUnblocker wrapper is missing nested app ($app_name).${NC}"
        integrity_failures=$((integrity_failures + 1))
    fi
    if [ -L "$shortcut_path" ] && [ -e "$shortcut_path" ]; then
        shortcut_target=$(readlink "$shortcut_path")
        echo -e "${GREEN}PASS: Launch shortcut exists and points to $shortcut_target${NC}"
    else
        echo -e "${RED}FAIL: Launch shortcut is missing or broken at $shortcut_path${NC}"
        integrity_failures=$((integrity_failures + 1))
    fi
fi

if [ "$integrity_failures" -eq 0 ]; then
    echo -e "${GREEN}Integrity check complete: all required checks passed.${NC}"
else
    echo -e "${RED}Integrity check complete: $integrity_failures required check(s) failed.${NC}"
fi

echo -e "${GREEN}Successfully finished running packageSpoofer.${NC}"

read -p "Press any key to exit packageSpoofer..."

###################
### Exploit End ###
###################

exit 0
