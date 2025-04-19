#!/bin/bash

# Determine paths relative to script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
PROJECT_NAME=$(basename "${PROJECT_ROOT}")

# Define build directory
BUILD_DIR="${PROJECT_ROOT}/build"
mkdir -p "${BUILD_DIR}"

# Set variables
APP_NAME="CopiloForXcode"
SCHEME_NAME="Copilot for Xcode"
CONFIGURATION="Release"
ARCHIVE_PATH="${BUILD_DIR}/Archives/${APP_NAME}.xcarchive"
XCWORKSPACE_PATH="${PROJECT_ROOT}/Copilot for Xcode.xcworkspace"
EXPORT_PATH="${BUILD_DIR}/Export"
EXPORT_OPTIONS_PLIST="${PROJECT_ROOT}/Script/export-options-local.plist"

# Clean and build archive
xcodebuild \
    -scheme "${SCHEME_NAME}" \
    -quiet \
    -archivePath "${ARCHIVE_PATH}" \
    -configuration "${CONFIGURATION}" \
    -skipMacroValidation \
    -showBuildTimingSummary \
    -disableAutomaticPackageResolution \
    -workspace "${XCWORKSPACE_PATH}" -verbose -arch arm64 \
    archive \
    APP_VERSION='0.0.0'

# Export archive to .app
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -exportPath "${EXPORT_PATH}"

echo "App packaged successfully at ${EXPORT_PATH}/${APP_NAME}.app"

open "${EXPORT_PATH}"