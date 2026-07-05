import XCTest

/// End-to-end coverage of the core journey: launch on the landing screen, run a
/// search, and confirm the results list renders. The app is launched with the
/// `-uiTestStubData` argument (see `Support/UITestSupport.swift`), which swaps
/// the live Google/location layers for deterministic stubs — so these tests need
/// no network, no API key, and no location permission.
final class LandingFlowUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  private func launchStubbedApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-uiTestStubData"]
    app.launch()
    return app
  }

  /// Landing → type a location → the two stubbed courts appear in the list.
  func testTextSearchShowsResults() {
    let app = launchStubbedApp()

    let searchField = app.textFields.firstMatch
    XCTAssertTrue(
      searchField.waitForExistence(timeout: 5), "Landing search field should be present")

    searchField.tap()
    // Trailing "\n" fires the keyboard's search key, which triggers the field's
    // onSubmit. (Tapping the magnifyingglass button is ambiguous — it shares the
    // "Search" accessibility label with the keyboard's return key.)
    searchField.typeText("Seattle\n")

    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Results list should show the first stubbed court")
    XCTAssertTrue(
      app.staticTexts["Green Lake Pickleball"].exists,
      "Results list should show the second stubbed court")
  }

  /// Landing → "Near me" resolves the stubbed location and shows the same list.
  func testNearMeShowsResults() {
    let app = launchStubbedApp()

    let nearMe = app.buttons["Near me"]
    XCTAssertTrue(nearMe.waitForExistence(timeout: 5), "Near me button should be present")
    nearMe.tap()

    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Near me should populate the results list")
  }
}
