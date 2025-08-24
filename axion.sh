#!/bin/bash

# Local TimeZone
sudo rm -rf /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

rm -rf .repo/local_manifests && \
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs && \
git clone https://github.com/Shravan55555/local_manifest.git --depth 1 -b main .repo/local_manifests && \
/opt/crave/resync.sh && \
export BUILD_USERNAME=shravan && \
export BUILD_HOSTNAME=crave && \
export TZ=Asia/Kolkata && \
source build/envsetup.sh && \
axion RMX1901 user gms pico && \
make installclean && \
curl -sSL https://raw.githubusercontent.com/Shravan55555/Signing-Script/main/keygen.sh | bash && \
ax -br
