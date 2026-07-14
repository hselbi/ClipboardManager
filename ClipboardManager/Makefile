# ClipboardManager Makefile
# Use this to generate Xcode project and build

.PHONY: all setup generate build clean help

# Default target
all: setup generate

# Install dependencies (XcodeGen)
setup:
	@echo "Checking for XcodeGen..."
	@which xcodegen > /dev/null || (echo "Installing XcodeGen..." && brew install xcodegen)
	@echo "XcodeGen is ready!"

# Generate Xcode project from project.yml
generate:
	@echo "Generating Xcode project..."
	xcodegen generate
	@echo "Project generated! Open ClipboardManager.xcodeproj"

# Build macOS app (Debug)
build-macos:
	@echo "Building macOS app..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-macOS \
		-configuration Debug \
		-destination 'platform=macOS' \
		build

# Build macOS app (Release)
build-macos-release:
	@echo "Building macOS app (Release)..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-macOS \
		-configuration Release \
		-destination 'platform=macOS' \
		build

# Build iOS app (Debug) for simulator
build-ios:
	@echo "Building iOS app..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-iOS \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		build

# Build iOS app (Release)
build-ios-release:
	@echo "Building iOS app (Release)..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-iOS \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		build

# Archive macOS app
archive-macos:
	@echo "Archiving macOS app..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-macOS \
		-configuration Release \
		-archivePath build/ClipboardManager-macOS.xcarchive \
		archive

# Archive iOS app
archive-ios:
	@echo "Archiving iOS app..."
	xcodebuild -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-iOS \
		-configuration Release \
		-archivePath build/ClipboardManager-iOS.xcarchive \
		archive

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -rf build/
	rm -rf DerivedData/
	xcodebuild clean -project ClipboardManager.xcodeproj -scheme ClipboardManager-macOS || true
	xcodebuild clean -project ClipboardManager.xcodeproj -scheme ClipboardManager-iOS || true
	@echo "Clean complete!"

# Open project in Xcode
open:
	@open ClipboardManager.xcodeproj

# Run tests
test:
	@echo "Running tests..."
	xcodebuild test -project ClipboardManager.xcodeproj \
		-scheme ClipboardManager-macOS \
		-destination 'platform=macOS'

# Format code with SwiftFormat (if installed)
format:
	@which swiftformat > /dev/null && swiftformat . || echo "SwiftFormat not installed. Run: brew install swiftformat"

# Lint code with SwiftLint (if installed)
lint:
	@which swiftlint > /dev/null && swiftlint || echo "SwiftLint not installed. Run: brew install swiftlint"

# Help
help:
	@echo "ClipboardManager Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  setup              Install XcodeGen (requires Homebrew)"
	@echo "  generate           Generate Xcode project from project.yml"
	@echo "  build-macos        Build macOS app (Debug)"
	@echo "  build-macos-release Build macOS app (Release)"
	@echo "  build-ios          Build iOS app (Debug, Simulator)"
	@echo "  build-ios-release  Build iOS app (Release)"
	@echo "  archive-macos      Archive macOS app"
	@echo "  archive-ios        Archive iOS app"
	@echo "  clean              Clean build artifacts"
	@echo "  open               Open project in Xcode"
	@echo "  test               Run tests"
	@echo "  format             Format code with SwiftFormat"
	@echo "  lint               Lint code with SwiftLint"
	@echo "  help               Show this help message"
