#!/bin/bash
rm -rf .repo/local_manifests && \
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs && \
git clone https://github.com/shravansayz/local_manifests.git --depth 1 -b axion .repo/local_manifests && \
export BUILD_USERNAME=shravan && \
export BUILD_HOSTNAME=android-build && \
export TZ=Asia/Kolkata && \
source build/envsetup.sh && \
axion RMX1901 user gms pico && \
make installclean && \
curl -sSL https://raw.githubusercontent.com/Shravan55555/Signing-Script/main/keygen.sh | bash && \
ax -br
