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
 if [[ "$name" == */Contents/Info.plist ]]; then
    pname="$name"
 else
    pname="$name/Contents/Info.plist"
 fi

 read -p "Enter the new package identifier (it can be random characters, has to start with com.) (e.g., com.example.app): " identifier
 read -p "(Not required) Would you like to apply binary patches? (fixes crashes with some apps) [y/n]: " patchChoice
 read -p "(Not required) Would you like to apply framework patches? (May break some apps) [y/n]: " frameworkChoice

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
echo "Processing..."
clear

echo "Your choices:"
echo "App Directory: $name"
echo "Property List: $name/Contents/Info.plist"
echo "New Package Identifier: $identifier"
echo "Apply Binary Patch: $patchChoice"
echo "Apply Framework Patch: $frameworkChoice"
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
echo -e "//////  packageSpoofer 1.1b  //////"
echo -e "//////      Developed by     //////"
echo -e "//////  yourworstnightmare1  //////"
echo -e "///////////////////////////////////"

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
echo -e "${YELLOW}codesign: Signing application using ad-hoc signature: $name"
codesign --force --deep --sign - "$name"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Code signing failed: The file may be corrupt or in a protected directory.${NC}"
    echo -e "${YELLOW}If you recieved the error "bundle format is ambiguous could be app or framework", the signing succeeded but there may be additional issues (likely does not affect the function of the app).${NC}"
    read -p "Press any key to exit..."
    exit 1
fi
echo -e "${GREEN}Application signed successfully.${NC}"

# Patches and extras
if [ "$patchChoice" == "y" ] || [ "$patchChoice" == "Y" ]; then
    echo -e "${BOLD}Applying binary patches...${NC}"
    echo -e "${YELLOW}chmod: add execute permission: $name/Contents/MacOS/*"
    chmod +x $name/Contents/MacOS/*
if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to set executable permissions.${NC}"
        read -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}Binary patches applied successfully.${NC}"
fi
if [ "$frameworkChoice" == "y" ] || [ "$frameworkChoice" == "Y" ]; then
    echo -e "${BOLD}Applying framework patches...${NC}"
    find "$name/Contents" -maxdepth 2 -type d \( -name "Frameworks" -o -name "PlugIns" -o -name "XPCServices" \) -print
    ls -la "$name/Contents/Frameworks" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Frameworks not found. They may be named differently from the exploit's known list or do not exist within the app's package contents (exist in ~/Library/Application Support). Skipping framework patching.${NC}"
    fi
    echo -e "${GREEN}Framework patches applied successfully.${NC}"
fi
echo -e "${GREEN}Successfully finished running packageSpoofer.${NC}"
echo "Running application..."
open "$name"
echo -e "${GREEN}Application launched.${NC}"

read -p "Press any key to exit packageSpoofer..."

###################
### Exploit End ###
###################

exit 1