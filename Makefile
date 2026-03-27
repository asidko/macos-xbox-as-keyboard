APP_NAME = XboxAsKeyboard
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CERT_P12 = certs/dev.p12
CERT_PASS = temp123
CERT_NAME = XboxAsKeyboard Dev
KEYCHAIN = $(HOME)/Library/Keychains/login.keychain-db

.PHONY: build run install clean setup-cert

setup-cert:
	@security find-identity -v -p codesigning | grep -q "$(CERT_NAME)" || (echo "Importing dev certificate..." && security import $(CERT_P12) -k $(KEYCHAIN) -T /usr/bin/codesign -P "$(CERT_PASS)" && echo "Certificate imported.")

build: setup-cert
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp $(BUILD_DIR)/$(APP_NAME) "$(APP_BUNDLE)/Contents/MacOS/"
	cp Info.plist "$(APP_BUNDLE)/Contents/"
	codesign --force --sign "$(CERT_NAME)" "$(APP_BUNDLE)"
	@echo "Signed with $(CERT_NAME)"

run: build
	open "$(APP_BUNDLE)"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf .build
