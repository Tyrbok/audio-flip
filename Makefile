PROJECT := AudioFlip.xcodeproj
SCHEME := AudioFlip
BUILD_DIR := build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
INSTALL_DERIVED_DATA := $(BUILD_DIR)/InstallDerivedData
RELEASE_DIR := $(BUILD_DIR)/release
APP_PATH := $(abspath $(DERIVED_DATA)/Build/Products/Debug/AudioFlip.app)
RELEASE_APP_PATH := $(DERIVED_DATA)/Build/Products/Release/AudioFlip.app
INSTALL_RELEASE_APP_PATH := $(INSTALL_DERIVED_DATA)/Build/Products/Release/AudioFlip.app
INSTALL_DIR ?= $(HOME)/Applications
INSTALL_APP_PATH := $(INSTALL_DIR)/AudioFlip.app
INSTALL_SIGNING_IDENTITY ?= -
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
ARCHIVE_APP_PATH := $(RELEASE_DIR)/AudioFlip.xcarchive/Products/Applications/AudioFlip.app
ARCHIVE_INTERMEDIATE_APP_PATH := $(DERIVED_DATA)/Build/Intermediates.noindex/ArchiveIntermediates/AudioFlip/BuildProductsPath/Release/AudioFlip.app
HOST_ARCH := $(shell uname -m)
MACOS_DESTINATION := generic/platform=macOS
VERSION := 0.1.0

.PHONY: help prepare-build build test run clean unregister-build-apps archive release install uninstall package check

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

prepare-build:
	@mkdir -p "$(BUILD_DIR)"
	@touch "$(BUILD_DIR)/.metadata_never_index"

build: prepare-build ## Build the development app
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build
	@$(MAKE) --no-print-directory unregister-build-apps

test: prepare-build ## Run the automated XCTest suite
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination 'platform=macOS,arch=$(HOST_ARCH)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO test
	@$(MAKE) --no-print-directory unregister-build-apps

run: build ## Build, restart, and open AudioFlip
	@running_pids=$$(pgrep -x AudioFlip || true); \
	if [ -n "$$running_pids" ]; then \
		kill -TERM $$running_pids 2>/dev/null || true; \
		for attempt in 1 2 3 4 5 6 7 8 9 10; do \
			pgrep -x AudioFlip >/dev/null || break; \
			sleep 0.2; \
		done; \
		if pgrep -x AudioFlip >/dev/null; then \
			printf 'AudioFlip did not stop after SIGTERM\n' >&2; \
			exit 1; \
		fi; \
	fi
	open -a "$(APP_PATH)"
	@$(MAKE) --no-print-directory unregister-build-apps

clean: unregister-build-apps ## Remove generated build and release artifacts
	rm -rf $(BUILD_DIR)

unregister-build-apps:
	@for app in \
		"$(APP_PATH)" \
		"$(RELEASE_APP_PATH)" \
		"$(INSTALL_RELEASE_APP_PATH)" \
		"$(ARCHIVE_APP_PATH)" \
		"$(ARCHIVE_INTERMEDIATE_APP_PATH)"; do \
		if [ -d "$$app" ]; then \
			$(LSREGISTER) -u "$$app" >/dev/null 2>&1 || true; \
		fi; \
	done
	@if [ -d "$(INSTALL_APP_PATH)" ]; then $(LSREGISTER) -f "$(INSTALL_APP_PATH)" >/dev/null 2>&1 || true; fi

archive: prepare-build ## Create an unsigned Xcode release archive
	mkdir -p $(RELEASE_DIR)
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) -archivePath $(RELEASE_DIR)/AudioFlip.xcarchive CODE_SIGNING_ALLOWED=NO archive
	@$(MAKE) --no-print-directory unregister-build-apps

release: prepare-build ## Build the Release app
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build
	@$(MAKE) --no-print-directory unregister-build-apps

install: prepare-build ## Build and install AudioFlip in INSTALL_DIR (defaults to ~/Applications)
	xcodebuild -quiet -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(MACOS_DESTINATION)' -derivedDataPath $(INSTALL_DERIVED_DATA) CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY="$(INSTALL_SIGNING_IDENTITY)" build
	mkdir -p "$(INSTALL_DIR)"
	ditto "$(INSTALL_RELEASE_APP_PATH)" "$(INSTALL_APP_PATH)"
	@$(LSREGISTER) -u "$(INSTALL_RELEASE_APP_PATH)" >/dev/null 2>&1 || true
	rm -rf "$(INSTALL_RELEASE_APP_PATH)"
	@$(MAKE) --no-print-directory unregister-build-apps

uninstall: ## Remove AudioFlip from INSTALL_DIR (defaults to ~/Applications)
	@test -n "$(strip $(INSTALL_DIR))" || { echo "INSTALL_DIR must not be empty" >&2; exit 1; }
	@if [ -d "$(INSTALL_APP_PATH)" ]; then \
		$(LSREGISTER) -u "$(INSTALL_APP_PATH)" >/dev/null 2>&1 || true; \
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
