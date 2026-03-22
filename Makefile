APP     = EdexUI.app
BINARY  = .build/release/EdexUI
VERSION ?= dev

.PHONY: all build app sign dmg run clean

all: app

## Build the release binary
build:
	swift build -c release --arch arm64

## Assemble a runnable .app bundle from the release binary
app: build
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	@cp $(BINARY)                             $(APP)/Contents/MacOS/EdexUI
	@cp Sources/EdexUI/Info.plist             $(APP)/Contents/Info.plist
	@cp Sources/EdexUI/Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	@echo "→ $(APP) assembled"

## Ad-hoc sign the bundle (required to run on your own machine without notarization)
sign: app
	codesign --force --deep --sign - $(APP)
	@echo "→ ad-hoc signed"

## Create a distributable DMG
dmg: sign
	@rm -rf dmg-staging
	@mkdir -p dmg-staging
	@cp -R $(APP) dmg-staging/
	@ln -s /Applications dmg-staging/Applications
	hdiutil create \
		-volname "EdexUI" \
		-srcfolder dmg-staging \
		-ov \
		-format UDZO \
		EdexUI-$(VERSION)-arm64.dmg
	@rm -rf dmg-staging
	@echo "→ EdexUI-$(VERSION)-arm64.dmg"

## Build and run immediately (debug build, faster)
run:
	swift run

## Remove all build artifacts
clean:
	rm -rf .build $(APP) dmg-staging EdexUI-*.dmg
