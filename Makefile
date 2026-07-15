# Sports Tracker — developer tasks.
# Targets: build · test (test-core, test-sportrecord) · lint · format · format-check · ci

PROJECT       := SportsTracker/SportsTracker.xcodeproj
SCHEME        := SportsTracker
BUILD_DEST    := generic/platform=iOS Simulator
TEST_DEST     := platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5
XCFLAGS       := -skipPackagePluginValidation
# Pin the test run to English so locale-sensitive assertions (localized strings)
# are deterministic regardless of the host/simulator language.
TESTFLAGS     := -testLanguage en -testRegion US
FORMAT_PATHS  := Modules/Core/Sources Modules/SportRecord/Sources SportsTracker/SportsTracker
FORMAT_CONFIG := --configuration .swift-format

.PHONY: build test test-core test-sportrecord lint format format-check ci

# Build the app (runs the SwiftLint plugin)
build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(BUILD_DEST)' $(XCFLAGS)

# Run all package tests
test: test-core test-sportrecord

test-core:
	cd Modules/Core && xcodebuild test -scheme Core -destination '$(TEST_DEST)' $(XCFLAGS) $(TESTFLAGS)

test-sportrecord:
	cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination '$(TEST_DEST)' $(XCFLAGS) $(TESTFLAGS)

# Lint everything with the SwiftLint CLI
lint:
	swiftlint lint

# Format sources in place with swift-format
format:
	swift format $(FORMAT_CONFIG) --recursive --in-place $(FORMAT_PATHS)

# Check formatting without writing (fails on diffs)
format-check:
	swift format lint --strict $(FORMAT_CONFIG) --recursive $(FORMAT_PATHS)

# Full check pipeline
ci: format-check lint build test
