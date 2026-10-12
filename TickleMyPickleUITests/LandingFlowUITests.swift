import XCTest

/// End-to-end coverage of the core journey: launch on the landing screen, run a
/// search, and confirm the results list renders. The app is launched with the
/// `-uiTestStubData` argument (see `Support/UITestSupport.swift`), which swaps
/// the live Google/location layers for deterministic stubs — so these tests need
/// no network, no API key, and no location permission.
@MainActor
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

  /// On launch the search field takes focus: the keyboard comes up on its own
  /// and the search pill sits just above it, with the header card above that.
  func testKeyboardOpensOnLaunchWithSearchAboveIt() throws {
    let app = launchStubbedApp()

    let field = app.textFields["Search location"]
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Landing search field should be present")
    let focused = expectation(
      for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
    wait(for: [focused], timeout: 3)

    // A simulator using the Mac's hardware keyboard (as CI's may) never shows
    // the on-screen one, so placement can only be checked when it appears.
    let keyboard = app.keyboards.firstMatch
    guard keyboard.waitForExistence(timeout: 3) else {
      throw XCTSkip("No on-screen keyboard (hardware keyboard connected); focus checked only")
    }

    // Wait out the keyboard's slide-in before measuring.
    let settled = expectation(for: NSPredicate { _, _ in
      field.frame.maxY <= keyboard.frame.minY
    }, evaluatedWith: nil)
    wait(for: [settled], timeout: 3)

    let wordmark = app.staticTexts["Tickle My Pickle"]
    XCTAssertTrue(wordmark.exists, "Header card should still show")
    XCTAssertLessThan(wordmark.frame.maxY, field.frame.minY, "Header card should be above the search pill")

    // Docked means the pill hugs the keyboard, not the card. Compared rather
    // than measured against a fixed number: the keyboard element's frame
    // starts below the predictive-text bar, whose height varies by device.
    let gapBelow = keyboard.frame.minY - field.frame.maxY
    let gapAbove = field.frame.minY - wordmark.frame.maxY
    XCTAssertLessThan(
      gapBelow, gapAbove,
      "Search pill should sit just above the keyboard (\(Int(gapBelow))pt) rather than near the card (\(Int(gapAbove))pt)")

    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "landing-keyboard"
    screenshot.lifetime = .keepAlways
    add(screenshot)
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
      app.buttons["Ballard Community Court"].waitForExistence(timeout: 5),
      "Results list should show the first stubbed court")
    XCTAssertTrue(
      app.buttons["Green Lake Pickleball"].exists,
      "Results list should show the second stubbed court")
  }

  /// The Saved tab is untappable until something is actually saved, and it
  /// re-disables when the last save is undone.
  func testSavedTabIsDisabledUntilACourtIsSaved() {
    let app = launchStubbedApp()

    let nearMe = app.buttons["Near me"]
    XCTAssertTrue(nearMe.waitForExistence(timeout: 5), "Near me button should be present")
    nearMe.tap()

    let savedTab = app.buttons["Saved"].firstMatch
    XCTAssertTrue(savedTab.waitForExistence(timeout: 5), "Saved tab should be present")
    XCTAssertFalse(savedTab.isEnabled, "Saved tab should be disabled with no saved courts")

    let star = app.buttons["Save court"].firstMatch
    XCTAssertTrue(star.waitForExistence(timeout: 5), "Save button should be present on a row")
    star.tap()
    XCTAssertTrue(savedTab.isEnabled, "Saving a court should enable the Saved tab")

    // Unsaving the only court from the Saved tab must drop us back on Nearby
    // rather than stranding the view on a tab that can't be tapped.
    savedTab.tap()
    app.buttons["Remove from saved"].firstMatch.tap()
    XCTAssertFalse(savedTab.isEnabled, "Removing the last save should disable the Saved tab again")
    XCTAssertTrue(
      app.buttons["Green Lake Pickleball"].waitForExistence(timeout: 5),
      "Should fall back to the Nearby list, which shows every stubbed court")
  }

  /// Landing → "Near me" resolves the stubbed location and shows the same list.
  func testNearMeShowsResults() {
    let app = launchStubbedApp()

    let nearMe = app.buttons["Near me"]
    XCTAssertTrue(nearMe.waitForExistence(timeout: 5), "Near me button should be present")
    nearMe.tap()

    XCTAssertTrue(
      app.buttons["Ballard Community Court"].waitForExistence(timeout: 5),
      "Near me should populate the results list")
  }
}
