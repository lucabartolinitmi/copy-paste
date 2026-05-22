BINARY      = CopyPaste
BUILD_DIR   = .build/release
APP_BUNDLE  = $(BINARY).app
CONTENTS    = $(APP_BUNDLE)/Contents

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
	@echo "✓ Built $(APP_BUNDLE)"

install: bundle
	cp -r "$(APP_BUNDLE)" "/Applications/$(APP_BUNDLE)"
	@echo "✓ Installed to /Applications/$(APP_BUNDLE)"

run: bundle
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
