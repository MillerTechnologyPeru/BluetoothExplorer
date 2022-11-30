#!/bin/bash
set -e
source swift-define

echo "Generate SwiftPM cross compilation toolchain file"
rm -f ${SWIFTPM_DESTINATION_FILE}
mkdir -p $SRC_ROOT/swift/toolchain
touch ${SWIFTPM_DESTINATION_FILE}

printf "{\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"version\":1,\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"sdk\":\"${SRC_ROOT}/swift/toolchain/android-ndk-r25b/toolchains/llvm/prebuilt/darwin-x86_64/sysroot\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"toolchain-bin-dir\":\"${SWIFT_NATIVE_PATH}\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"target\":\"${SWIFT_TARGET_NAME}\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"dynamic-library-extension\":\"so\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"extra-cc-flags\":[\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "      \"-fPIC\"\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   ],\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"extra-swiftc-flags\":[\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "      \"-target\", \"${SWIFT_TARGET_NAME}\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "      \"-resource-dir\", \"${SWIFT_SDK_PATH}/usr/lib/swift\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "      \"-tools-directory\", \"${SRC_ROOT}/swift/toolchain/android-ndk-r25b/toolchains/llvm/prebuilt/darwin-x86_64/bin\",\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   ],\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   \"extra-cpp-flags\":[\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "      \"-lstdc++\"\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "   ]\n" >> ${SWIFTPM_DESTINATION_FILE}
printf "}\n" >> ${SWIFTPM_DESTINATION_FILE}
