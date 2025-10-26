#!/bin/bash

# =================================================================
#                     Lunaris-AOSP Build Script
# =================================================================
#
# Stop the script immediately if any command fails
set -e

# =======================
#   SETUP & PRE-CHECKS
# =======================

# Load environment variables from .env file (optional)
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
  echo ".env file loaded successfully."
else
  echo "Warning: .env file not found! Continuing without environment variables."
  echo "Telegram notifications and Pixeldrain upload will be skipped."
fi

# Telegram notification function (only if tokens are available)
send_telegram_message() {
    if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
            --data-urlencode "chat_id=$TG_CHAT_ID" \
            --data-urlencode "text=$1" \
            --data-urlencode "parse_mode=Markdown" > /dev/null
    else
        echo "Telegram notification skipped: TG_BOT_TOKEN or TG_CHAT_ID not set"
        echo "Message would have been: $1"
    fi
}

# Trap to send a notification on script failure (only if tokens are available)
handle_exit() {
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        send_telegram_message "❌ *Build Failed!*

The script exited with a non-zero status code: \`$EXIT_CODE\`.
Please check the logs for the exact error."
    fi
}

# Only set trap if Telegram tokens are available
if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    trap handle_exit EXIT
    # Send "Build Started" notification
    send_telegram_message "🚀 *New Build Started for RMX1901!*

The build process has been initiated. I will notify you upon completion or failure."
else
    echo "Build started for RMX1901 - Telegram notifications disabled"
fi

# === Exports ===
BUILD_START_TIME=$(date +%s)
export BUILD_USERNAME=shravan 
export BUILD_HOSTNAME=crave


# =======================
#   1. CLEANUP SECTION
# =======================

echo "Cleaning up patched repositories..."
(cd system/netd && git reset --hard && git clean -fd) || echo "netd not found, skipping."
(cd system/bpf && git reset --hard && git clean -fd) || echo "bpf not found, skipping."
(cd packages/modules/Connectivity && git reset --hard && git clean -fd) || echo "Connectivity not found, skipping."
(cd frameworks/base && git reset --hard && git clean -fd) || echo "frameworks/base not found, skipping."

echo "Cleaning up cloned repositories..."
rm -rf prebuilts/clang/host/linux-x86/clang-proton
rm -rf device/realme/RMX1901
rm -rf vendor/realme/RMX1901
rm -rf kernel/realme/sdm710

echo "Performing selective cleanup of 'out' directory..."
rm -rf out/target/product/RMX1901/system
rm -rf out/target/product/RMX1901/product
echo "Cleanup finished."


# =======================
#   2. REPO INITIALIZATION & SYNC
# =======================
echo "Initializing Lunaris-AOSP repository..."
repo init -u https://github.com/Lunaris-AOSP/android -b 16 --git-lfs

echo "Syncing sources..."
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
else
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
fi


# =======================
#   3. APPLYING CHERRY-PICKS
# =======================
echo "Applying cherry-picks for system/netd..."
(cd system/netd && \
    (git remote | grep -q 'kader' || git remote add kader https://github.com/kaderbava/android_system_netd) && \
    git fetch kader && \
    git cherry-pick 38b09861dabf0dd0296dbe6be55a1b291d38458d..f61cb1b69638c928a71dae134230b53f8d6872ac)

echo "Applying cherry-picks for system/bpf..."
(cd system/bpf && \
    (git remote | grep -q 'kader' || git remote add kader https://github.com/kaderbava/android_system_bpf) && \
    git fetch kader && \
    git cherry-pick 96747e69935e23db7f960f59016467400a90f0ce..2b93ce502e9bab67597ecf64fb2776cd1e653e87)

echo "Applying cherry-picks for packages/modules/Connectivity..."
(cd packages/modules/Connectivity && \
    (git remote | grep -q 'kader' || git remote add kader https://github.com/kaderbava/android_packages_modules_Connectivity) && \
    git fetch kader && \
    git cherry-pick 399ea327815ad1f758edb37f27b6f30bf9bb3723..023602a2b37f3d7eeeaa4d4982a214f23c739666)

echo "Applying cherry-picks for frameworks/base..."
(cd frameworks/base && \
    (git remote | grep -q 'dain' || git remote add dain https://github.com/dain09/android_frameworks_base) && \
    git fetch dain && \
    git cherry-pick f88def7b540da6cbeea1412f9f5387cc3de656ef)

# =======================
#   4. CLONING ADDITIONAL REPOSITORIES
# =======================
echo "Cloning additional repositories..."
git clone https://github.com/kdrag0n/proton-clang --depth 1  prebuilts/clang/host/linux-x86/clang-proton
git clone https://github.com/shravansayz/device_realme_RMX1901_ -b luna16 --depth 1 device/realme/RMX1901
git clone https://github.com/shravansayz/vendor_realme_RMX1901 --depth 1 -b 16 vendor/realme/RMX1901
git clone https://github.com/dain09/android_kernel_realme_sdm710-fork -b r5p --depth 1 kernel/realme/sdm710


# =======================
#   5. SETUP SIGNING KEYS & APPLY DT2W PATCH
# =======================
echo "Setting up private signing keys..."
wget https://github.com/shravansayz/local_manifests/raw/keys/keys.zip && \
unzip -o keys.zip -d vendor/lunaris-priv/ && \
rm keys.zip && \
echo "Signing keys setup completed!"

echo "Applying frameworks/base DT2W patch..."
cd frameworks/base
# Check if DT2W patch is already applied
if git log --oneline | grep -q "dt2w\|DT2W\|double.*tap"; then
    echo "DT2W patch already applied, skipping..."
else
    echo "Downloading and applying DT2W patch..."
    wget -O temp.patch "https://github.com/shravansayz/android_frameworks_base/commit/7809e13937efaf85b319bc28d3b88326342ec1df.patch"
    if git apply temp.patch; then
        git add .
        git commit -m "Apply DT2W patch"
        echo "DT2W patch applied successfully!"
    else
        echo "Patch conflicts detected, continuing build without DT2W patch..."
    fi
    rm -f temp.patch
fi
cd ../..
echo "Frameworks/base patch process completed!"


# =======================
#   6. BUILD THE ROM
# =======================
echo "Starting the build process..."
source b*/env*
lunch lineage_RMX1901-bp2a-user

echo "Running 'm installclean' for a safe build..."
m installclean

echo "Starting the main build..."
m lunaris

send_telegram_message "✅ *Build Finished Successfully!*

Now preparing to upload the file..."


# =======================
#   7. UPLOAD THE BUILD (Optional - only if Pixeldrain API key is available)
# =======================
echo "Starting the upload process..."

# === Stop Build Timer and Calculate Duration ===
BUILD_END_TIME=$(date +%s)
DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
DURATION_FORMATTED=$(printf '%dh:%dm:%ds\n' $(($DURATION/3600)) $(($DURATION%3600/60)) $(($DURATION%60)))

OUTPUT_DIR="out/target/product/RMX1901"
ZIP_FILE=$(find "$OUTPUT_DIR" -type f -iname "Lunaris-AOSP*.zip" -printf "%T@ %p\n" | sort -n | tail -n1 | cut -d' ' -f2-)

if [[ -f "$ZIP_FILE" ]]; then
  if [ -n "$PIXELDRAIN_API_KEY" ]; then
    echo "Uploading $ZIP_FILE to Pixeldrain..."
    RESPONSE=$(curl -s -u ":$PIXELDRAIN_API_KEY" -X POST -F "file=@$ZIP_FILE" https://pixeldrain.com/api/file)
    FILE_ID=$(echo "$RESPONSE" | jq -r '.id')
    
    if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
      DOWNLOAD_URL="https://pixeldrain.com/u/$FILE_ID"
      FILE_NAME=$(basename "$ZIP_FILE")
      FILE_SIZE_BYTES=$(stat -c%s "$ZIP_FILE")
      FILE_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$FILE_SIZE_BYTES")
      UPLOAD_DATE=$(date +"%Y-%m-%d %H:%M")
      
      echo "Upload successful: $DOWNLOAD_URL"
      UPLOAD_MESSAGE="🎉 *RMX1901 Upload Complete!*

*Build Time:* \`$DURATION_FORMATTED\`
📎 *Filename:* \`$FILE_NAME\`
📦 *Size:* $FILE_SIZE_HUMAN
🕓 *Uploaded:* $UPLOAD_DATE
🔗 [Download Link]($DOWNLOAD_URL)"
      send_telegram_message "$UPLOAD_MESSAGE"
    else
      echo "Upload failed. Pixeldrain response: $RESPONSE"
      send_telegram_message "❌ *Upload Failed!*

The build was successful, but the upload to Pixeldrain failed.
*Response:* \`$RESPONSE\`"
    fi
  else
    echo "Pixeldrain API key not available. Skipping upload."
    echo "Build completed successfully. File: $ZIP_FILE"
    send_telegram_message "✅ *Build Finished Successfully!*

*Build Time:* \`$DURATION_FORMATTED\`
📎 *Filename:* \`$(basename "$ZIP_FILE")\`
📦 *Size:* $(numfmt --to=iec --suffix=B $(stat -c%s "$ZIP_FILE"))

Upload was skipped (no Pixeldrain API key configured)."
  fi
else
  echo "Error: No .zip file found in $OUTPUT_DIR"
  send_telegram_message "❌ *Upload Failed!*

The build seemed to complete, but no .zip file was found in \`$OUTPUT_DIR\`."
fi

echo "Script finished."

# Unset the trap explicitly for a clean successful exit
if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    trap - EXIT
fi
