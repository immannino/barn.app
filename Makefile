PREFIX ?= /Applications
APP = build/barn.app

.PHONY: build app run install uninstall cli icon release publish site test clean

build:
	swift build

app:
	./scripts/build-app.sh

run: app
	-pkill -x barn
	open $(APP)

install: app
	-pkill -x barn
	rm -rf "$(PREFIX)/barn.app"
	cp -R $(APP) "$(PREFIX)/"
	open "$(PREFIX)/barn.app"

# `barn hook <harness>` and `barn --dump` on your PATH.
cli:
	ln -sf "$(PREFIX)/barn.app/Contents/MacOS/barn" /usr/local/bin/barn

uninstall:
	-pkill -x barn
	rm -rf "$(PREFIX)/barn.app" /usr/local/bin/barn

icon:
	./scripts/make-icns.sh

release:
	./scripts/release.sh $(VERSION)

# make publish VERSION=0.2.0 [TAP_DIR=../homebrew-tap]
publish:
	TAP_DIR=$(TAP_DIR) ./scripts/publish.sh $(VERSION)

clean:
	rm -rf .build build

test:
	swift test

# Preview the website at http://localhost:8000
site:
	cd site && python3 -m http.server 8000
