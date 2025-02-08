#!/bin/bash

# Exit the script immediately if any command fails
set -e

# Define color variables for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print success messages with formatting
success_msg() {
    echo -e "${GREEN}=============${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}=============${NC}"
}

# Default values for ROM manifest URL, branch, device name, ROM name, build type, and whether to remove prebuilts
ROM_MANIFEST_URL=${1:-"https://github.com/RisingOS-Revived/android"}
ROM_BRANCH=${2:-"fifteen"}
DEVICE_NAME=${3:-"RMX1901"}
ROM_NAME=${4:-"lineage"}
CONFIG_TYPE=${5:-"ap4a"}
BUILD_TYPE=${6:-"user"}
REMOVE_PREBUILTS=${7:-"no"}  # Accept 'yes' or 'no' to remove prebuilts

# Starting message with the details of the build
echo -e "${CYAN}Starting ROM build for device: ${DEVICE_NAME}${NC}"
echo -e "${CYAN}ROM: ${ROM_NAME}, Branch: ${ROM_BRANCH}, Build type: ${BUILD_TYPE}${NC}"

# Remove prebuilts directory if specified
if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    echo -e "${YELLOW}Removing prebuilts directory...${NC}"
    rm -rf prebuilts
    success_msg "Prebuilts removed successfully!"
else
    echo -e "${YELLOW}Skipping prebuilts removal.${NC}"
    success_msg "Prebuilts removal skipped!"
fi

# Initialize the repo with the provided ROM manifest and branch
echo -e "${BLUE}Initializing repo with manifest: ${ROM_MANIFEST_URL} (branch: ${ROM_BRANCH})...${NC}"
repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
success_msg "Repo initialized successfully!"

# Set up local manifests by clearing and recreating the directory
echo -e "${BLUE}Setting up local manifests...${NC}"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

# Copy roomservice.xml to the local manifests directory
cp build_script/roomservice.xml .repo/local_manifests/
success_msg "Local manifests set up successfully!"

# Sync repositories with crave or traditional repo sync
if [ -f /opt/crave/resync.sh ]; then
    echo -e "${BLUE}Syncing repositories using crave resync...${NC}"
    /opt/crave/resync.sh
else
    echo -e "${YELLOW}/opt/crave/resync.sh not found. Falling back to traditional repo sync...${NC}"
    repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc --all)
fi
success_msg "Sync completed successfully!"

# Auto-sign build
echo -e "${YELLOW}Cloning Private Keys...${NC}"
rm -rf vendor/lineage-priv
git clone https://github.com/shravansayz/private_keys.git -b rise vendor/lineage-priv
success_msg "Keys generated successfully!"

#echo -e "${YELLOW}Cloning Custom...${NC}"
#wget https://raw.githubusercontent.com/custom-crdroid/custom_cr_setup/refs/heads/15.0/vendorsetup.sh
#bash vendorsetup.sh

# Set up the build environment and lunch for the specific device
echo -e "${BLUE}Configuring build environment...${NC}"
source build/envsetup.sh
lunch "${ROM_NAME}_${DEVICE_NAME}-${CONFIG_TYPE}-${BUILD_TYPE}"
success_msg "Build environment configured successfully!"

# Build the ROM using all available CPU cores
echo -e "${YELLOW}Building the ROM...${NC}"
mka installclean
mka bacon
success_msg "ROM built successfully!"

# Define the path to the built ROM zip file
BUILT_ROM_PATH="out/target/product/${DEVICE_NAME}/${ROM_NAME}*.zip"

# Attempt to pull the built ROM using crave
echo -e "${CYAN}Attempting to pull the built ROM from $BUILT_ROM_PATH...${NC}"
crave pull "$BUILT_ROM_PATH"

# Check if the pull command succeeded
if [ $? -eq 0 ]; then
    success_msg "ROM pulled successfully!"
else
    echo -e "${RED}=============${NC}"
    echo -e "${RED}Failed to pull the ROM zip file.${NC}"
    echo -e "${RED}=============${NC}"
    exit 1
fi
