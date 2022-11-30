#!/bin/bash
set -e
source swift-define

# Build with SwiftPM
$SWIFT_NATIVE_PATH/swift build \
    --destination $SWIFTPM_DESTINATION_FILE \
    --package-path $SWIFT_PACKAGE_SRC

# Copy compiled Swift package
mkdir -p $SRC_ROOT/app/src/main/jniLibs/$ANDROID_ARCH/
cp -rf $SWIFT_PACKAGE_SRC/.build/aarch64-unknown-linux-android24/debug/*.so \
    $SRC_ROOT/app/src/main/jniLibs/$ANDROID_ARCH/
