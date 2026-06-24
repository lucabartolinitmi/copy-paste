BINARY        = CopyPaste
BUILD_DIR     = .build/release
APP_BUNDLE    = $(BINARY).app
CONTENTS      = $(APP_BUNDLE)/Contents
SIGN_IDENTITY ?= CopyPaste Dev

.PHONY: all build bundle install clean run

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(CONTENTS)/MacOS"
	mkdir -p "$(CONTENTS)/Resources"
	cp "$(BUILD_DIR)/$(BINARY)" "$(CONTENTS)/MacOS/$(BINARY)"
	cp "Sources/CopyPaste/Info.plist" "$(CONTENTS)/Info.plist"
	@xattr -cr "$(APP_BUNDLE)" 2>/dev/null || true
	@if security find-identity -v -p codesigning | grep -q '"$(SIGN_IDENTITY)"'; then \
		codesign --force --deep --sign "$(SIGN_IDENTITY)" "$(APP_BUNDLE)" && \
		echo "✓ Built and signed with '$(SIGN_IDENTITY)' $(APP_BUNDLE)"; \
	else \
		echo "⚠️  Certificate '$(SIGN_IDENTITY)' not found — using ad-hoc signing."; \
		echo "   Create it once: Keychain Access → Certificate Assistant → Create a Certificate"; \
		echo "   Name: $(SIGN_IDENTITY), Type: Code Signing"; \
		codesign --force --deep --sign - "$(APP_BUNDLE)" && \
		echo "✓ Built and ad-hoc signed $(APP_BUNDLE)"; \
	fi

install: bundle
	@pkill -x $(BINARY) 2>/dev/null || true
	rm -rf "/Applications/$(APP_BUNDLE)"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_BUNDLE)"
	@echo "✓ Installed to /Applications/$(APP_BUNDLE)"
	open "/Applications/$(APP_BUNDLE)"
	@sleep 1
	@echo ""
	@echo "⚠️  Ad-hoc signing invalidates Input Monitoring on every rebuild."
	@echo "   Re-enable CopyPaste in System Settings → Privacy & Security → Input Monitoring"
	open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

run: bundle
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
