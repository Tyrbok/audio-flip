PROJECT := AudioFlip.xcodeproj
SCHEME := AudioFlip
BUILD_DIR := build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
RELEASE_DIR := $(BUILD_DIR)/release
APP_PATH := $(abspath $(DERIVED_DATA)/Build/Products/Debug/AudioFlip.app)
RELEASE_APP_PATH := $(DERIVED_DATA)/Build/Products/Release/AudioFlip.app
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_APP_PATH := $(INSTALL_DIR)/AudioFlip.app
HOST_ARCH := $(shell uname -m)
MACOS_DESTINATION := generic/platform=macOS
VERSION := 0.1.0

.PHONY: help build test run clean archive release install uninstall package check

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

release: ## Build the Release app
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build

install: release ## Install AudioFlip in INSTALL_DIR (defaults to ~/Applications)
	mkdir -p "$(INSTALL_DIR)"
	ditto "$(RELEASE_APP_PATH)" "$(INSTALL_APP_PATH)"

uninstall: ## Remove AudioFlip from INSTALL_DIR (defaults to ~/Applications)
	@test -n "$(strip $(INSTALL_DIR))" || { echo "INSTALL_DIR must not be empty" >&2; exit 1; }
	@if [ -d "$(INSTALL_APP_PATH)" ]; then \
		rm -rf "$(INSTALL_APP_PATH)"; \
		printf 'Removed %s\n' "$(INSTALL_APP_PATH)"; \
	else \
		printf 'AudioFlip is not installed at %s\n' "$(INSTALL_APP_PATH)"; \
	fi

package: release ## Zip AudioFlip.app for a GitHub Release or Cask
	mkdir -p $(RELEASE_DIR)
	ditto -c -k --norsrc --keepParent "$(RELEASE_APP_PATH)" "$(RELEASE_DIR)/AudioFlip-$(VERSION).zip"
	shasum -a 256 "$(RELEASE_DIR)/AudioFlip-$(VERSION).zip"

check: build test ## Run the local pre-commit build and test checks
