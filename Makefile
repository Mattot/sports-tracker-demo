# Sports Tracker — developer tasks.
# Targets: build · test (test-sportrecord) · lint · format · format-check · ci

PROJECT       := SportsTracker/SportsTracker.xcodeproj
SCHEME        := SportsTracker
BUILD_DEST    := generic/platform=iOS Simulator
TEST_DEST     := platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5
# The app target deploys to iOS 18.6+, so its tests need a newer runtime than
# the packages (which accept 18.0+). Override per-machine as with TEST_DEST.
APP_TEST_DEST := platform=iOS Simulator,name=iPhone 17,OS=26.5
XCFLAGS       := -skipPackagePluginValidation
# Pin the test run to English so locale-sensitive assertions (localized strings)
# are deterministic regardless of the host/simulator language.
TESTFLAGS     := -testLanguage en -testRegion US
FORMAT_PATHS  := Modules/Core/Sources Modules/SportRecord/Sources SportsTracker/SportsTracker
FORMAT_CONFIG := --configuration .swift-format

.PHONY: build test test-sportrecord test-app lint format format-check ci

# Build the app (runs the SwiftLint plugin)
build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(BUILD_DEST)' $(XCFLAGS)

# Run every suite: the SportRecord package plus the app target
test: test-sportrecord test-app

test-sportrecord:
	cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination '$(TEST_DEST)' $(XCFLAGS) $(TESTFLAGS)

# App-target tests (navigation/router). Needs an iOS 18.6+ simulator.
test-app:
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(APP_TEST_DEST)' -only-testing:SportsTrackerTests $(XCFLAGS) $(TESTFLAGS)

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
