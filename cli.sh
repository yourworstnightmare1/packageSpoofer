#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Known LSApplicationCategoryType values (same set as the GUI)
KNOWN_CATEGORIES=(
  "public.app-category.business"
  "public.app-category.developer-tools"
  "public.app-category.education"
  "public.app-category.entertainment"
  "public.app-category.finance"
  "public.app-category.games"
  "public.app-category.action-games"
  "public.app-category.adventure-games"
  "public.app-category.arcade-games"
  "public.app-category.board-games"
  "public.app-category.card-games"
  "public.app-category.casino-games"
  "public.app-category.dice-games"
  "public.app-category.educational-games"
  "public.app-category.family-games"
  "public.app-category.kids-games"
  "public.app-category.music-games"
  "public.app-category.puzzle-games"
  "public.app-category.racing-games"
  "public.app-category.role-playing-games"
  "public.app-category.simulation-games"
  "public.app-category.sports-games"
  "public.app-category.strategy-games"
  "public.app-category.trivia-games"
  "public.app-category.word-games"
  "public.app-category.graphics-design"
  "public.app-category.healthcare-fitness"
  "public.app-category.lifestyle"
  "public.app-category.medical"
  "public.app-category.music"
  "public.app-category.news"
  "public.app-category.photography"
  "public.app-category.productivity"
  "public.app-category.reference"
  "public.app-category.social-networking"
  "public.app-category.sports"
  "public.app-category.travel"
  "public.app-category.utilities"
  "public.app-category.video"
  "public.app-category.weather"
)

is_known_category() {
  local value="$1"
  local c
  for c in "${KNOWN_CATEGORIES[@]}"; do
    if [ "$c" = "$value" ]; then
      return 0
    fi
  done
  return 1
}

generate_random_bundle_id() {
  local chars='abcdefghijklmnopqrstuvwxyz0123456789'
  local seg1="" seg2="" i
  local len1=$((RANDOM % 8 + 2))
  local len2=$((RANDOM % 8 + 2))
  for ((i = 0; i < len1; i++)); do
    seg1+="${chars:RANDOM % ${#chars}:1}"
  done
  for ((i = 0; i < len2; i++)); do
    seg2+="${chars:RANDOM % ${#chars}:1}"
  done
  printf 'com.%s.%s' "$seg1" "$seg2"
}

clone_app_beside() {
  local source="$1"
  local parent base ext candidate index
  parent="$(dirname "$source")"
  base="$(basename "$source")"
  ext="${base##*.}"
  base="${base%.*}"
  candidate="$parent/${base} copy.${ext}"
  index=2
  while [ -e "$candidate" ]; do
    candidate="$parent/${base} copy ${index}.${ext}"
    index=$((index + 1))
  done
  cp -R "$source" "$candidate" || return 1
  printf '%s' "$candidate"
}

clear
echo -e "${BOLD}packageSpoofer CLI${NC}"
echo ""

read -p "Enter the directory of your app: " name
name="${name%\"}"; name="${name#\"}"
name="${name%\'}"; name="${name#\'}"
name="${name%/}"
name="$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [[ "$name" == */Contents/Info.plist ]]; then
  name="$(dirname "$(dirname "$name")")"
fi

app_name="$(basename "$name")"
if [ -f "$name/$app_name/Contents/Info.plist" ]; then
  is_wrapped=1
  patch_app="$name/$app_name"
else
  is_wrapped=0
  patch_app="$name"
fi
default_plist="$patch_app/Contents/Info.plist"
current_bundle_id=""
current_category=""
if [ -f "$default_plist" ]; then
  current_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$default_plist" 2>/dev/null || true)
  current_category=$(/usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$default_plist" 2>/dev/null || true)
fi

echo ""
echo "Bundle ID (leave empty to generate, or type an existing one):"
if [ -n "$current_bundle_id" ]; then
  echo -e "Current: ${YELLOW}${current_bundle_id}${NC}"
fi
read -p "New package identifier: " identifier
if [ -z "$identifier" ]; then
  identifier="$(generate_random_bundle_id)"
  echo -e "${GREEN}Generated Bundle ID: ${identifier}${NC}"
fi

echo ""
read -p "Info.plist path [${default_plist}]: " plist_path
plist_path="${plist_path:-$default_plist}"
plist_path="${plist_path%\"}"; plist_path="${plist_path#\"}"
plist_path="${plist_path%\'}"; plist_path="${plist_path#\'}"

echo ""
echo "Pre-Patch Scripts:"
read -p "(Not required) Clone Before Spoofing? [y/n]: " cloneChoice
read -p "(Not required) Remove Frameworks? (May break some apps) [y/n]: " frameworkChoice
targeted_frameworks=""
if [ "$frameworkChoice" == "y" ] || [ "$frameworkChoice" == "Y" ]; then
  echo "Targeted frameworks (comma-separated names/dylibs)."
  echo "Leave empty to delete the entire Contents/Frameworks folder."
  read -p "Targets: " targeted_frameworks
fi
read -p "(Not required) Make Executable (chmod +x)? [y/n]: " patchChoice
read -p "(Not required) Category Spoofer? [y/n]: " categoryChoice
category_type="$current_category"
if [ "$categoryChoice" == "y" ] || [ "$categoryChoice" == "Y" ]; then
  if [ -n "$current_category" ]; then
    echo -e "Current category: ${YELLOW}${current_category}${NC}"
  fi
  read -p "LSApplicationCategoryType value: " category_type
  if [ -n "$category_type" ] && ! is_known_category "$category_type"; then
    echo -e "${YELLOW}Warning: This is not a valid application category. This does not affect how the app runs but it may cause it to be more easily detectable by algorithms that use category-based blocking.${NC}"
  fi
fi

echo ""
echo "Post-Patch Scripts:"
read -p "(Not required) Apply appUnblocker? [y/n]: " appUnblockerChoice
read -p "(Not required) Bypass Gatekeeper (clear quarantine)? [y/n]: " gatekeeperChoice
read -p "(Not required) Hide File After Signing? [y/n]: " hideFileAfterSigningChoice
read -p "(Not required) Force Metal HUD? [y/n]: " forceMetalHUDChoice
if [ "$forceMetalHUDChoice" == "y" ] || [ "$forceMetalHUDChoice" == "Y" ]; then
  echo -e "${YELLOW}Duplicated bundle IDs conflicts with the Metal HUD patch, which will cause both apps to display the HUD unintentionally. Please use your own bundle ID or generate one.${NC}"
fi
read -p "(Not required) Open App on Completion? [y/n]: " openAppOnCompletionChoice
echo ""

if [ -z "$name" ] || [ -z "$identifier" ]; then
  echo -e "${RED}Error: App directory and package identifier are required.${NC}"
  read -p "Press any key to exit..."
  exit 1
fi

yn_label() {
  case "$1" in
    y|Y) echo "yes" ;;
    *) echo "no" ;;
  esac
}

echo "Your choices:"
echo "App Directory: $name"
echo "Info.plist: $plist_path"
echo "New Package Identifier: $identifier"
echo "Clone Before Spoofing: $(yn_label "$cloneChoice")"
echo "Remove Frameworks: $(yn_label "$frameworkChoice")"
if [ -n "$targeted_frameworks" ]; then
  echo "Targeted Frameworks: $targeted_frameworks"
fi
echo "Make Executable: $(yn_label "$patchChoice")"
echo "Category Spoofer: $(yn_label "$categoryChoice")"
if [ "$categoryChoice" == "y" ] || [ "$categoryChoice" == "Y" ]; then
  echo "Category: ${category_type:-<empty>}"
fi
echo "Apply AppUnblocker: $(yn_label "$appUnblockerChoice")"
echo "Bypass Gatekeeper: $(yn_label "$gatekeeperChoice")"
echo "Hide File After Signing: $(yn_label "$hideFileAfterSigningChoice")"
echo "Force Metal HUD: $(yn_label "$forceMetalHUDChoice")"
echo "Open App on Completion: $(yn_label "$openAppOnCompletionChoice")"
echo ""
read -p "Press any key to confirm and proceed..." -n1 -s
echo ""

#####################
### Exploit Begin ###
#####################

echo ""
echo -e "${BOLD}Starting...${NC}"
echo -e "///////////////////////////////////"
echo -e "//////  packageSpoofer 3.0.1  //////"
echo -e "//////      Developed by     //////"
echo -e "//////  yourworstnightmare1  //////"
echo -e "///////////////////////////////////"

if [ ! -d "$name" ]; then
  echo -e "${RED}Error: App bundle not found at $name${NC}"
  read -p "Press any key to exit..."
  exit 1
fi

volume_path=$(df "$name" | awk 'NR==2 {print $NF}')
if mount | grep " on ${volume_path} " | grep -q "read-only"; then
  echo -e "${RED}This is a read-only volume. packageSpoofer cannot use this volume.${NC}"
  echo ""
  echo "If you are trying to install an app from a .dmg file, move the app from the .dmg to any location on your system, then select the copied app."
  echo ""
  read -p "Press any key to exit..."
  exit 1
fi

if [ "$cloneChoice" == "y" ] || [ "$cloneChoice" == "Y" ]; then
  echo -e "${BOLD}[Pre-Patch] Cloning app before spoofing...${NC}"
  cloned_path="$(clone_app_beside "$name")" || {
    echo -e "${RED}Error: Failed to clone app.${NC}"
    read -p "Press any key to exit..."
    exit 1
  }
  echo -e "${GREEN}Cloned to: $cloned_path${NC}"
  name="$cloned_path"
  app_name="$(basename "$name")"
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
  # If user left the default plist path, retarget it to the clone.
  if [ "$plist_path" = "$default_plist" ]; then
    plist_path="$patch_app/Contents/Info.plist"
  fi
fi

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

if [ "$is_wrapped" -eq 1 ]; then
  echo -e "${YELLOW}Detected existing appUnblocker wrapper. Patching nested app: $patch_app${NC}"
fi

write_test_file="$patch_app/Contents/.packagespoofer_write_test"
if ! touch "$write_test_file" 2>/dev/null; then
  echo -e "${RED}Error: The app is not writable at $name${NC}"
  echo -e "${YELLOW}Copy the app to a writable folder (for example ~/Downloads) and try again.${NC}"
  read -p "Press any key to exit..."
  exit 1
fi
rm -f "$write_test_file"
echo -e "${GREEN}App location is writable.${NC}"

# Pre-patch
if [ "$frameworkChoice" == "y" ] || [ "$frameworkChoice" == "Y" ]; then
  echo -e "${BOLD}[Pre-Patch] Removing embedded frameworks...${NC}"
  frameworksPath="$patch_app/Contents/Frameworks"
  if [ -d "$frameworksPath" ]; then
    if [ -z "$targeted_frameworks" ]; then
      echo -e "${YELLOW}rm -rf $frameworksPath${NC}"
      rm -rf "$frameworksPath" || {
        echo -e "${RED}Error: Failed to remove frameworks.${NC}"
        read -p "Press any key to exit..."
        exit 1
      }
      echo -e "${GREEN}Frameworks folder removed successfully.${NC}"
    else
      IFS=',' read -r -a targets <<< "$targeted_frameworks"
      for raw_target in "${targets[@]}"; do
        target="$(printf '%s' "$raw_target" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$target" ] && continue
        for item in "$frameworksPath"/*; do
          [ -e "$item" ] || continue
          item_name="$(basename "$item")"
          item_base="${item_name%.*}"
          if [ "$item_name" = "$target" ] || [ "$item_name" = "${target}.framework" ] || [ "$item_name" = "${target}.dylib" ] || [ "$item_base" = "$target" ]; then
            echo -e "${YELLOW}rm -rf $item${NC}"
            rm -rf "$item"
          fi
        done
      done
      echo -e "${GREEN}Targeted frameworks processed.${NC}"
    fi
  else
    echo -e "${YELLOW}No embedded Frameworks folder found; skipping.${NC}"
  fi
fi

if [ "$patchChoice" == "y" ] || [ "$patchChoice" == "Y" ]; then
  echo -e "${BOLD}[Pre-Patch] Making executable (chmod +x)...${NC}"
  echo -e "${YELLOW}chmod +x $patch_app/Contents/MacOS/*${NC}"
  chmod +x "$patch_app"/Contents/MacOS/* 2>/dev/null || {
    echo -e "${RED}Error: Failed to set executable permissions.${NC}"
    read -p "Press any key to exit..."
    exit 1
  }
  echo -e "${GREEN}Make Executable applied successfully.${NC}"
fi

echo "Editing Info.plist..."
if [ ! -f "$plist_path" ]; then
  echo -e "${RED}Error: Info.plist not found at $plist_path${NC}"
  read -p "Press any key to exit..."
  exit 1
fi
echo -e "${YELLOW}Edit $plist_path: replace CFBundleIdentifier: string=$identifier${NC}"
plutil -replace CFBundleIdentifier -string "$identifier" "$plist_path" || {
  echo -e "${RED}Error: Failed to edit Info.plist: It is missing or corrupt.${NC}"
  read -p "Press any key to exit..."
  exit 1
}
echo -e "${GREEN}Info.plist bundle ID updated successfully.${NC}"

if [ "$categoryChoice" == "y" ] || [ "$categoryChoice" == "Y" ]; then
  if [ -z "$category_type" ]; then
    echo -e "${YELLOW}Category Spoofer enabled but category is empty; skipping.${NC}"
  else
    echo -e "${BOLD}[Pre-Patch] Setting LSApplicationCategoryType to: $category_type${NC}"
    if ! plutil -replace LSApplicationCategoryType -string "$category_type" "$plist_path" 2>/dev/null; then
      plutil -insert LSApplicationCategoryType -string "$category_type" "$plist_path" || {
        echo -e "${RED}Error: Failed to set LSApplicationCategoryType.${NC}"
        read -p "Press any key to exit..."
        exit 1
      }
    fi
    echo -e "${GREEN}Category updated successfully.${NC}"
  fi
fi

echo -e "${BOLD}Signing application...${NC}"
echo -e "${YELLOW}codesign: Signing application using ad-hoc signature: $patch_app${NC}"
codesign --force --deep --sign - "$patch_app"
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Code signing failed: The file may be corrupt or in a protected directory.${NC}"
  echo -e "${YELLOW}If you received the error \"bundle format is ambiguous could be app or framework\", the signing succeeded but there may be additional issues.${NC}"
  read -p "Press any key to exit..."
  exit 1
fi
echo -e "${GREEN}Application signed successfully.${NC}"

# Post-patch
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

if [ "$gatekeeperChoice" == "y" ] || [ "$gatekeeperChoice" == "Y" ]; then
  echo -e "${BOLD}[Post-Patch] Bypassing Gatekeeper (clear quarantine)...${NC}"
  xattr -dr com.apple.quarantine "$name" 2>/dev/null || true
  echo -e "${GREEN}Quarantine attribute cleared (or was already absent).${NC}"
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

if [ "$forceMetalHUDChoice" == "y" ] || [ "$forceMetalHUDChoice" == "Y" ]; then
  echo -e "${BOLD}[Post-Patch] Forcing Metal HUD for ${identifier}...${NC}"
  if defaults write "$identifier" MetalForceHudEnabled -bool YES; then
    echo -e "${GREEN}Metal HUD enabled for $identifier.${NC}"
  else
    echo -e "${YELLOW}WARN: Could not enable Metal HUD for $identifier.${NC}"
  fi
fi

if [ "$openAppOnCompletionChoice" == "y" ] || [ "$openAppOnCompletionChoice" == "Y" ]; then
  echo -e "${BOLD}[Post-Patch] Opening app on completion...${NC}"
  open "$patch_app" && echo -e "${GREEN}Opened $patch_app${NC}" || echo -e "${YELLOW}WARN: Could not open $patch_app${NC}"
fi

# Integrity checks
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

if [ "$categoryChoice" == "y" ] || [ "$categoryChoice" == "Y" ]; then
  if [ -n "$category_type" ]; then
    actual_category=$(/usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$integrity_app/Contents/Info.plist" 2>/dev/null)
    if [ "$actual_category" == "$category_type" ]; then
      echo -e "${GREEN}PASS: Category matches ($category_type).${NC}"
    else
      echo -e "${RED}FAIL: Category mismatch (expected $category_type, found ${actual_category:-none}).${NC}"
      integrity_failures=$((integrity_failures + 1))
    fi
  fi
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
exit 0
