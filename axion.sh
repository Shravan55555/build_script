#!/bin/bash

# Exit on any error
set -e

# Remove existing local manifests and initialize repo
rm -rf .repo/local_manifests
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs

# Create local manifests directory and manifest file
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/local_manifest.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
        <remote  name="ghub"
                fetch="https://github.com" />
        <remote  name="glab"
                fetch="https://gitlab.com" />
 
 <!-- Device Trees --> 
 <project path="device/realme/RMX1901" name="shravansayz/device_realme_RMX1901_" remote="ghub" revision="derp" />
	
 <!-- Vendor Trees -->
 <project path="vendor/realme/RMX1901" name="shravansayz/vendor_realme_RMX1901_" remote="ghub" revision="16" clone-depth="1" />
	
 <!-- Kernel Trees-->
 <project path="kernel/realme/sdm710" name="shravansayz/android_kernel_realme_sdm710_" remote="ghub" revision="16.0" clone-depth="1" />
 <!-- Proton clang -->
 <project path="prebuilts/clang/host/linux-x86/clang-proton" name="kdrag0n/proton-clang" remote="ghub" revision="master" clone-depth="1" />
 <!-- packages_modules_Connectivity -->
<remove-project name="android_packages_modules_Connectivity" />
<project path="packages/modules/Connectivity" name="ij-israfil/packages_modules_Connectivity" remote="ghub" revision="16" />
<!-- system_netd -->
<remove-project name="android_system_netd" />
<project path="system/netd" name="ij-israfil/system_netd" remote="ghub" revision="16" />
 <!-- system_bpf -->
<remove-project name="android_system_bpf" />
<project path="system/bpf" name="ij-israfil/system_bpf" remote="ghub" revision="16" />
<!-- device_qcom_sepolicy_vndr -->
<remove-project name="LineageOS/android_device_qcom_sepolicy_vndr" />
<project path="device/qcom/sepolicy_vndr/legacy-um" name="shravansayz/android_device_qcom_sepolicy_vndr" remote="ghub" revision="bka-legacy-um" />
 	
 <!-- android_hardware_qcom_audio -->
 <remove-project name="LineageOS/android_hardware_qcom_audio" />
 <project path="hardware/qcom-caf/sdm845/audio" name="israfilbd/android_hardware_qcom_audio" remote="ghub" revision="lineage-22.2-caf-sdm845" />
 <project path="hardware/qcom-caf/sm8350/audio" name="israfilbd/android_hardware_qcom_audio" remote="ghub" revision="lineage-22.2-caf-sm8350" />
</manifest>
EOF

# Sync repositories
echo "Syncing repositories..."
/opt/crave/resync.sh

# Set build environment variables
export BUILD_USERNAME=shravan
export BUILD_HOSTNAME=android-build
export TZ=Asia/Kolkata

# Setup build environment and start build
echo "Setting up build environment..."
source build/envsetup.sh
echo "Starting build for RMX1901..."
axion RMX1901 userdebug gms pico
make installclean
ax -br
