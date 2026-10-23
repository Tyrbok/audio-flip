PROJECT := AudioFlip.xcodeproj
SCHEME := AudioFlip
BUILD_DIR := build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
RELEASE_DIR := $(BUILD_DIR)/release
APP_PATH := $(DERIVED_DATA)/Build/Products/Debug/AudioFlip.app
RELEASE_APP_PATH := $(DERIVED_DATA)/Build/Products/Release/AudioFlip.app
HOST_ARCH := $(shell uname -m)
MACOS_DESTINATION := generic/platform=macOS
VERSION := 0.1.0

.PHONY: help build test run clean archive package check

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the development app
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build

test: ## Run the automated XCTest suite
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'platform=macOS,arch=$(HOST_ARCH)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO test

run: build ## Build and open AudioFlip (macOS reuses an already running instance)
	open -a "$(APP_PATH)"

clean: ## Remove generated build and release artifacts
	rm -rf $(BUILD_DIR)

archive: ## Create an unsigned Xcode release archive
	mkdir -p $(RELEASE_DIR)
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) -archivePath $(RELEASE_DIR)/AudioFlip.xcarchive CODE_SIGNING_ALLOWED=NO archive

package: ## Build and zip AudioFlip.app for a GitHub Release or Cask
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build
	mkdir -p $(RELEASE_DIR)
	ditto -c -k --norsrc --keepParent "$(RELEASE_APP_PATH)" "$(RELEASE_DIR)/AudioFlip-$(VERSION).zip"
	shasum -a 256 "$(RELEASE_DIR)/AudioFlip-$(VERSION).zip"

check: build test ## Run the local pre-commit build and test checks
