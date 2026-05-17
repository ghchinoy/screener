.PHONY: help build run clean

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the release binary and package it into Screener.app
	@echo "Building release binary..."
	swift build -c release
	@echo "Packaging into Screener.app..."
	mkdir -p Screener.app/Contents/MacOS
	mkdir -p Screener.app/Contents/Resources
	cp .build/release/screener Screener.app/Contents/MacOS/
	cp -R .build/release/*.bundle Screener.app/Contents/Resources/ 2>/dev/null || true
	cp Assets/Info.plist Screener.app/Contents/
	cp Assets/AppIcon.icns Screener.app/Contents/Resources/
	@echo "Done! You can now run 'make run' or 'open Screener.app'"

run: build ## Build the app and open it
	@echo "Launching Screener.app..."
	open Screener.app

clean: ## Remove build artifacts and the app bundle
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build
	rm -rf Screener.app
	@echo "Clean complete."

reset-db: ## Delete the local SwiftData store to fix migration crashes during development
	@echo "Deleting default.store..."
	rm -rf ~/Library/Application\ Support/default.store*
	rm -rf ~/Library/Application\ Support/Video\ Screener/default.store*
	rm -rf ~/Library/Containers/com.example.screener/Data/Library/Application\ Support/default.store*
	@echo "Database reset complete."
