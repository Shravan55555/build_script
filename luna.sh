#!/bin/bash

# Minimal ROM build script with Telegram notifications
version=v2.4.1
set -e

# Load configuration
source config.ini || { echo "Error occurred while parsing config.ini"; exit 1; }

# Colors for output
Red='\033[1;31m'
Green='\033[1;32m'
Cyan='\033[1;36m'
Reset='\033[0m'

# Configuration
CODENAME="RMX1901"
ROM_NAME="Lunaris"
LUNCH_TARGET="lineage_${CODENAME}-bp2a-user"
BUILD_TARGET="lunaris"

# Build info
export BUILD_USERNAME=shravan
export BUILD_HOSTNAME=crave
export TZ=Asia/Kolkata

print() {
    echo -e "$*"
    if [ "$telegram" = "true" ]; then
        local clean_message=$(echo -e "$*" | sed -r "s/\x1B\[[0-9;]*[mK]//g")
        telegram "$clean_message"
    fi
}

telegram() {
    if [ "$telegram" = "true" ]; then
        curl -s "https://api.telegram.org/bot$telegramtoken/sendMessage" \
             -d "chat_id=$chat_id" \
             -d "text=$1" \
             -d "parse_mode=HTML" > /dev/null
    fi
}

error() {
    print "╰─ ${Red}Error${Reset} | $*"
    exit 1
}

success() {
    print "╰─ ${Green}Success${Reset} | $*"
}

# Validate required config
if [ "$telegram" = "true" ]; then
    if [ "$telegramtoken" = "" ] || [ "$chat_id" = "" ]; then
        error "Telegram token or chat_id is empty in config.ini"
    fi
fi

# Start build process
start_time=$(date +%s)
print "╭─ ${Cyan}Starting ${ROM_NAME} build${Reset} | BuildDroid ${version}"
print "├─ ${Cyan}Device${Reset}: ${CODENAME}"

# Clean and prepare
print "├─ ${Cyan}Cleaning local manifests${Reset}"
rm -rf .repo/local_manifests

# Initialize repo
print "├─ ${Cyan}Initializing Lunaris AOSP repository${Reset}"
repo init -u https://github.com/Lunaris-AOSP/android -b 16 --git-lfs || error "Failed to initialize repo"

# Clone local manifests
print "├─ ${Cyan}Cloning device manifests${Reset}"
git clone https://github.com/shravansayz/local_manifests.git --depth 1 -b luna16 .repo/local_manifests || error "Failed to clone local manifests"

# Sync sources
print "├─ ${Cyan}Syncing ROM sources${Reset}"
/opt/crave/resync.sh || error "Failed to sync sources"

# Download and extract signing keys
print "├─ ${Cyan}Setting up signing keys${Reset}"
wget -q https://github.com/shravansayz/local_manifests/raw/keys/keys.zip || error "Failed to download keys"
unzip -o keys.zip -d vendor/lineage-priv/ > /dev/null || error "Failed to extract keys"
rm -f keys.zip

# Setup build environment
print "├─ ${Cyan}Setting up build environment${Reset}"
source build/envsetup.sh || error "Failed to source build environment"

# Lunch device
print "├─ ${Cyan}Lunching ${LUNCH_TARGET}${Reset}"
lunch ${LUNCH_TARGET} || error "Failed to lunch target"

# Clean build
print "├─ ${Cyan}Cleaning previous build artifacts${Reset}"
make installclean > /dev/null || error "Failed to clean build"

# Start build
print "├─ ${Cyan}Starting ${ROM_NAME} build${Reset}"
build_start=$(date +%s)
m ${BUILD_TARGET} || error "Build failed"

# Calculate build time
build_time=$(($(date +%s) - build_start))
total_time=$(($(date +%s) - start_time))

# Format time
format_time() {
    local time=$1
    local hours=$((time / 3600))
    local minutes=$(((time % 3600) / 60))
    local seconds=$((time % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Find ROM file
ROM_DIR="out/target/product/${CODENAME}"
if [ -d "$ROM_DIR" ]; then
    ROM_FILE=$(find "$ROM_DIR" -name "*.zip" -type f | head -1)
    if [ -n "$ROM_FILE" ]; then
        ROM_SIZE=$(du -h "$ROM_FILE" | cut -f1)
        success "Build completed in $(format_time $total_time)"
        print "├─ ${Green}ROM file${Reset}: $(basename "$ROM_FILE") (${ROM_SIZE})"
        print "╰─ ${Green}Location${Reset}: $ROM_FILE"
        
        # Send detailed build info via Telegram
        if [ "$telegram" = "true" ]; then
            build_info="<b>Build Success ✅</b>
<b>ROM:</b> ${ROM_NAME}
<b>Device:</b> ${CODENAME}
<b>File:</b> $(basename "$ROM_FILE")
<b>Size:</b> ${ROM_SIZE}
<b>Build Time:</b> $(format_time $build_time)
<b>Total Time:</b> $(format_time $total_time)"
            telegram "$build_info"
        fi
    else
        error "No ROM file found in $ROM_DIR"
    fi
else
    error "Output directory $ROM_DIR not found"
fi
