APP_NAME = XboxAsKeyboard
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CERT_P12 = certs/dev.p12
CERT_PASS = temp123
CERT_NAME = XboxAsKeyboard Dev
KEYCHAIN = $(HOME)/Library/Keychains/login.keychain-db

.PHONY: build build-release build-universal run install clean setup-cert

setup-cert:
	@security find-identity -v -p codesigning | grep -q "$(CERT_NAME)" || (echo "Importing dev certificate..." && security import $(CERT_P12) -k $(KEYCHAIN) -T /usr/bin/codesign -P "$(CERT_PASS)" && echo "Certificate imported.")

generate-build-info:
	@echo 'let buildVersion = "$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")"' > Sources/BuildInfo.swift
	@echo 'let buildHash = "$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")"' >> Sources/BuildInfo.swift

# Dev build: uses local cert so Accessibility permission persists
build: setup-cert generate-build-info
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp $(BUILD_DIR)/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	codesign --force --sign "$(CERT_NAME)" "$(APP_BUNDLE)"
	@echo "Signed with $(CERT_NAME)"

# CI/release: universal binary (ARM + Intel in one app)
build-universal: generate-build-info
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp .build/apple/Products/Release/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	codesign --force --sign - "$(APP_BUNDLE)"
	@echo "Universal binary built (arm64 + x86_64)"

# CI/release: current arch only
build-release: generate-build-info
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp $(BUILD_DIR)/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"
	codesign --force --sign - "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

dmg: build-universal
	rm -rf dmg-staging XboxAsKeyboard.dmg
	mkdir -p dmg-staging
	cp -R "$(APP_BUNDLE)" dmg-staging/
	ln -s /Applications dmg-staging/Applications
	hdiutil create -volname "XboxAsKeyboard" -srcfolder dmg-staging -ov -format UDZO XboxAsKeyboard.dmg
	rm -rf dmg-staging
	@echo "Created XboxAsKeyboard.dmg"

clean:
	swift package clean
	rm -rf .build dmg-staging XboxAsKeyboard.dmg
