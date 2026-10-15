.PHONY: test build app

test:
	swift test

build:
	swift build -c release

app:
	bash scripts/make-app.sh
