import XCTest

/// Accessibility checks on the landing and results screens: Apple's built-in
/// audit (contrast, hit areas, Dynamic Type, clipping, labels), plus explicit
/// checks for touch-target size, button placement, and what VoiceOver reads.
/// Uses the same `-uiTestStubData` stubs as `LandingFlowUITests`.
///
/// Problems that exist today are recorded rather than allowed to fail the
/// suite. Audit findings go in `knownAuditIssues`. Elsewhere they're wrapped in
/// `XCTExpectFailure`, which turns into a failure once the problem is fixed,
/// so the test can't silently keep excusing it.
@MainActor
final class AccessibilityUITests: XCTestCase {
  /// Apple's minimum touch target (Human Interface Guidelines).
  private let minimumTarget: CGFloat = 44

  override func setUp() {
    continueAfterFailure = true
  }

  private func launchStubbedApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-uiTestStubData"]
    app.launch()
    XCTAssertTrue(
      app.textFields.firstMatch.waitForExistence(timeout: 5), "Landing search field should be present")
    return app
  }

  private func showResults(_ app: XCUIApplication) {
    app.buttons["Near me"].tap()
    XCTAssertTrue(
      app.buttons["Ballard Community Court"].waitForExistence(timeout: 5),
      "Near me should populate the results list")
  }

  // MARK: - Apple's accessibility audit

  func testLandingScreenPassesAccessibilityAudit() throws {
    let app = launchStubbedApp()
    // The field takes focus on launch; audit the screen as people see it,
    // after the keyboard has finished sliding in. (A simulator using the Mac's
    // hardware keyboard never shows one, so don't fail on its absence.)
    _ = app.keyboards.firstMatch.waitForExistence(timeout: 5)
    Thread.sleep(forTimeInterval: 1)
    try app.performAccessibilityAudit { issue in self.isKnown(issue) }
  }

  func testResultsScreenPassesAccessibilityAudit() throws {
    let app = launchStubbedApp()
    showResults(app)
    try app.performAccessibilityAudit { issue in self.isKnown(issue) }
  }

  /// Audit findings that exist today, as (type, element label). Anything not
  /// listed here fails the audit tests. Remove an entry once it's fixed.
  private let knownAuditIssues: [(XCUIAccessibilityAuditType, String)] = [
    // Too-small touch target; see testTouchTargetsAreAtLeast44Points.
    (.hitRegion, "Nearby"),
    // Low contrast; see AccessibilityColorTests.testKnownLowContrastPairings.
    (.contrast, "Find pickleball courts near you"),
    (.contrast, "1471 NW 67th St"),
    (.contrast, "7201 E Green Lake Dr N"),
    (.contrast, "★ 4.7  (128)"),
    (.contrast, "★ 4.5  (96)"),
    // Number badges on rows and map pins: white on terracotta.
    (.contrast, "1"), (.contrast, "2"), (.contrast, "3"), (.contrast, "4"), (.contrast, "5"),
    // Amenity badges scale with Dynamic Type, but the audit still reports
    // partial support. It couldn't see them while they were labeled with the
    // disclaimer. Not truncation, the capsule clip, or the text-style curve
    // (all tried).
    (.dynamicType, "Outdoor"), (.dynamicType, "Free"),
  ]

  /// Findings that aren't ours to fix, or that the audit gets wrong.
  private let ignoredAuditIssues: [(XCUIAccessibilityAuditType, String)] = [
    // MapKit's own "Legal" link.
    (.hitRegion, "Legal"),
    // Disabled controls are exempt from WCAG contrast.
    (.contrast, "Saved"),
    // Court blue on white measures 7.2:1 (AccessibilityColorTests); the audit
    // seems to sample the pill's shadow or border instead.
    (.contrast, "Near me"),
    // Single-line names, addresses, and the placeholder are truncated on
    // purpose to keep rows and the pill a fixed height.
    (.textClipped, "Search location"),
    (.textClipped, "Ballard Community Court"),
    (.textClipped, "Green Lake Pickleball"),
    (.textClipped, "1471 NW 67th St"),
    (.textClipped, "7201 E Green Lake Dr N"),
  ]

  private func isKnown(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
    // MapKit's own street labels have no element to attach the finding to.
    guard let label = issue.element?.label else { return issue.auditType == .elementDetection }
    return (knownAuditIssues + ignoredAuditIssues).contains { type, known in
      type == issue.auditType && known == label
    }
  }

  // MARK: - Touch targets and placement

  func testTouchTargetsAreAtLeast44Points() {
    let app = launchStubbedApp()
    showResults(app)

    // Tapping anywhere in the pill focuses the field, so only its width counts.
    assertTarget(app.textFields["Search location"], minimumWidth: minimumTarget, minimumHeight: 0)

    for element in [
      app.buttons["Search"],
      app.buttons["Near me"],
      app.buttons["Save court"].firstMatch,
      // iOS 27 exposes the SwiftUI Link as a link, but iOS 26 (the CI
      // runner) doesn't, so match by name whatever its element type. The
      // control comes before its text in the tree, so firstMatch is the
      // tappable one.
      app.descendants(matching: .any)["Directions"].firstMatch,
    ] {
      assertTarget(element)
    }

    // Too small today (33pt tall): the tab bar was kept at its original height.
    for (name, element) in [("Nearby tab", app.buttons["Nearby"]), ("Saved tab", app.buttons["Saved"])] {
      XCTExpectFailure("Known small touch target: \(name)") {
        assertTarget(element)
      }
    }
  }

  /// Every control is fully on screen, below the status bar, and doesn't
  /// overlap another control (overlapping hit areas steal taps).
  func testControlsAreOnScreenAndDoNotOverlap() {
    let app = launchStubbedApp()

    for screen in ["landing", "results"] {
      if screen == "results" { showResults(app) }

      let window = app.windows.firstMatch.frame
      // The status bar and Dynamic Island sit in roughly the top 54pt.
      let usable = window.inset(by: UIEdgeInsets(top: 54, left: 0, bottom: 0, right: 0))
      // The landing screen opens with the keyboard up; its keys are the
      // system's, not ours, and some of them overlap by design.
      let keyboard = app.keyboards.firstMatch
      let keyboardFrame = keyboard.exists ? keyboard.frame : .null
      let controls =
        (app.buttons.allElementsBoundByIndex + app.links.allElementsBoundByIndex
        + app.textFields.allElementsBoundByIndex)
        .filter { $0.exists && $0.isHittable && $0.label != "Legal" }
        .filter { !keyboardFrame.contains($0.frame) }
        .map { (label: $0.label, frame: $0.frame) }
      XCTAssertFalse(controls.isEmpty, "\(screen): found no controls to check")

      for control in controls {
        // The list scrolls, so the last visible row can be cut off by the
        // bottom edge; only the top and sides have to be in bounds.
        let frame = control.frame
        XCTAssertTrue(
          frame.minY >= usable.minY && frame.minX >= usable.minX && frame.maxX <= usable.maxX
            && frame.minY < usable.maxY,
          "\(screen): '\(control.label)' at \(control.frame) is off screen or under the status bar")
      }
      for (i, a) in controls.enumerated() {
        for b in controls[(i + 1)...] where a.frame.intersects(b.frame) {
          XCTFail("\(screen): '\(a.label)' \(a.frame) overlaps '\(b.label)' \(b.frame)")
        }
      }
    }
  }

  // MARK: - VoiceOver

  func testControlsHaveSpokenLabels() {
    let app = launchStubbedApp()
    showResults(app)

    for button in app.buttons.allElementsBoundByIndex where button.exists && button.isHittable {
      XCTAssertFalse(button.label.isEmpty, "A button at \(button.frame) has no VoiceOver label")
    }
    // Labels describe the action, not the icon's symbol name.
    XCTAssertTrue(app.buttons["Search"].exists, "Search button should be labeled \"Search\"")
    XCTAssertTrue(app.buttons["Save court"].firstMatch.exists, "Star should be labeled \"Save court\"")
  }

  func testSavingACourtUpdatesTheStarsSpokenLabel() {
    let app = launchStubbedApp()
    showResults(app)

    app.buttons["Save court"].firstMatch.tap()
    XCTAssertTrue(
      app.buttons["Remove from saved"].firstMatch.waitForExistence(timeout: 2),
      "After saving, VoiceOver should hear \"Remove from saved\"")
  }

  /// VoiceOver reads each badge's name ("Indoor", "Lighted", ...), not the
  /// disclaimer, which is only a hint.
  func testAmenityBadgesAreReadAloud() {
    let app = launchStubbedApp()
    showResults(app)

    XCTAssertTrue(
      app.staticTexts["Outdoor"].firstMatch.exists, "VoiceOver should read the \"Outdoor\" badge")
  }

  /// Tapping a row selects that court; VoiceOver users select it by
  /// activating the court name, which is exposed as a button.
  func testCourtRowsAreSelectableWithVoiceOver() {
    let app = launchStubbedApp()
    showResults(app)

    let name = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ballard Community Court"))
      .firstMatch
    XCTAssertTrue(name.exists, "Each court row should be a button VoiceOver can activate")
    name.tap()
    XCTAssertTrue(name.isSelected, "The court just selected should be marked selected")
  }

  /// VoiceOver should say which tab is current.
  func testCurrentTabIsMarkedSelected() {
    let app = launchStubbedApp()
    showResults(app)

    XCTAssertTrue(app.buttons["Nearby"].isSelected, "The Nearby tab should be marked selected")
    XCTAssertFalse(app.buttons["Saved"].isSelected, "The Saved tab should not be marked selected")
  }

  // MARK: - Helpers

  private func assertTarget(
    _ element: XCUIElement, minimumWidth: CGFloat? = nil, minimumHeight: CGFloat? = nil,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let width = minimumWidth ?? minimumTarget
    let height = minimumHeight ?? minimumTarget
    XCTAssertTrue(element.exists, "'\(element.label)' should exist", file: file, line: line)
    let size = element.frame.size
    // Frames come back with floating-point noise (a 44pt view can measure
    // 43.99999999999994), so allow a hair under the minimum.
    let tolerance: CGFloat = 0.01
    XCTAssertTrue(
      size.width >= width - tolerance && size.height >= height - tolerance,
      "'\(element.label)' is \(Int(size.width))x\(Int(size.height))pt; needs at least \(Int(width))x\(Int(height))",
      file: file, line: line)
  }
}
