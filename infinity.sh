#!/bin/bash

# Telegram Bot Configuration (Base64 encoded for GitHub raw script)
# To generate: echo -n "your_bot_token" | base64
_tb64="WU9VUl9CT1RfVE9LRU5fSEVSRQ=="  # Replace with your base64 encoded bot token
_cb64="WU9VUl9DSEFUX0lEX0hFUkU="      # Replace with your base64 encoded chat ID

# Decode credentials
TELEGRAM_BOT_TOKEN=$(echo "$_tb64" | base64 -d)
TELEGRAM_CHAT_ID=$(echo "$_cb64" | base64 -d)

# Security measures
set +x  # Hide commands from logs
unset _tb64 _cb64  # Clear encoded variables
trap 'unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID' EXIT  # Clean up on exit

# Function to send Telegram notifications
send_telegram() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${message}" \
            -d "parse_mode=${parse_mode}" \
            -d "disable_web_page_preview=true" > /dev/null 2>&1
    fi
}

# Function to get build info
get_build_info() {
    echo "🔧 <b>Build Info:</b>
📱 Device: RMX1901
🏗️ ROM: ProjectInfinity-X
🌿 Branch: 16
👤 Builder: ${BUILD_USERNAME:-shravan}
🖥️ Host: ${BUILD_HOSTNAME:-crave}
🕐 Started: $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

# Start notification
send_telegram "$(get_build_info)

🚀 <b>Build Started!</b>
📋 Initializing repository and syncing sources..."

echo "🔄 Starting Android build process..."

# Original build commands with error handling
set -e
trap 'send_telegram "❌ <b>Build Failed!</b>
🚨 Error occurred during: $BASH_COMMAND
⏰ Time: $(date '+%H:%M:%S')"' ERR

# Repository setup
echo "📦 Cleaning and initializing repository..."
rm -rf .repo/local_manifests && \
repo init --depth=1 --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault && \
git clone https://github.com/shravansayz/local_manifests.git --depth 1 -b infinity .repo/local_manifests && \

send_telegram "📥 <b>Repository Sync Started</b>
⏳ Syncing source code... This may take a while."

/opt/crave/resync.sh && \

# Environment setup
export BUILD_USERNAME=shravan
export BUILD_HOSTNAME=crave
export TZ=Asia/Kolkata

send_telegram "🔑 <b>Setting up build environment</b>
⚙️ Configuring keys and environment variables..."

# Keys setup
wget https://github.com/shravansayz/local_manifests/raw/keys/keys.zip && unzip -o keys.zip -d vendor/lineage-priv/ && rm keys.zip && \

# Build environment
source build/envsetup.sh && \
lunch infinity_RMX1901-user && \

send_telegram "🧹 <b>Cleaning previous build</b>
🗑️ Running installclean..."

make installclean

send_telegram "🔨 <b>Build Compilation Started!</b>
⚡ Running 'm bacon' - this will take some time...
⏱️ Started at: $(date '+%H:%M:%S')"

# Start time tracking
BUILD_START_TIME=$(date +%s)

# Main build command
m bacon

# Calculate build time
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
BUILD_TIME_FORMATTED=$(printf '%02d:%02d:%02d' $((BUILD_DURATION/3600)) $((BUILD_DURATION%3600/60)) $((BUILD_DURATION%60)))

# Success notification
send_telegram "✅ <b>Build Completed Successfully!</b>

📱 <b>Device:</b> RMX1901
🏗️ <b>ROM:</b> ProjectInfinity-X
⏱️ <b>Build Time:</b> ${BUILD_TIME_FORMATTED}
🕐 <b>Completed:</b> $(date '+%Y-%m-%d %H:%M:%S %Z')
👤 <b>Builder:</b> ${BUILD_USERNAME}

🎉 Your ROM is ready!"

echo "✅ Build completed successfully!"
echo "📊 Total build time: ${BUILD_TIME_FORMATTED}"
