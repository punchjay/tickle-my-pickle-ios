import XCTest

/// Drives the app through its marketing-worthy states and attaches a
/// full-screen PNG at each one, for App Store product-page screenshots.
/// Runs against the same `-uiTestStubData` stubs as `LandingFlowUITests`,
/// so it needs no network, API key, or location permission.
///
/// To produce the App Store's required 6.9″ size (1320×2868), run on an
/// iPhone 17 Pro Max simulator with a clean status bar:
///
///   xcrun simctl boot "iPhone 17 Pro Max"
///   xcrun simctl status_bar "iPhone 17 Pro Max" override \
///     --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4
///   xcodebuild test -project TickleMyPickle.xcodeproj -scheme TickleMyPickle \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' \
///     -only-testing:TickleMyPickleUITests/StoreScreenshotUITests \
///     -resultBundlePath screenshots.xcresult
///   xcrun xcresulttool export attachments --path screenshots.xcresult \
///     --output-path screenshots/
final class StoreScreenshotUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func testCaptureStoreScreenshots() {
    let app = XCUIApplication()
    app.launchArguments += ["-uiTestStubData"]
    app.launch()

    let searchField = app.textFields.firstMatch
    XCTAssertTrue(
      searchField.waitForExistence(timeout: 5), "Landing search field should be present")
    attachScreenshot(named: "01-landing")

    searchField.tap()
    searchField.typeText("Seattle\n")
    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Results list should render the stubbed courts")
    // Map tiles stream in asynchronously and the camera animates to frame the
    // pins; give both time to settle so the capture isn't half-loaded.
    Thread.sleep(forTimeInterval: 4)
    attachScreenshot(named: "02-results")

    app.staticTexts["Salmon Bay Indoor Rec Center"].tap()
    Thread.sleep(forTimeInterval: 2) // selection recenters the map
    attachScreenshot(named: "03-selected")

    // Save the first two courts (each tap flips that row's label to "Remove
    // from saved", so firstMatch advances to the next unsaved row).
    app.buttons["Save court"].firstMatch.tap()
    app.buttons["Save court"].firstMatch.tap()
    let savedTab = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH 'Saved ('"),
    ).firstMatch
    XCTAssertTrue(savedTab.waitForExistence(timeout: 5), "Saved tab should be present")
    savedTab.tap()
    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Saved tab should list the saved court")
    attachScreenshot(named: "04-saved")
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
