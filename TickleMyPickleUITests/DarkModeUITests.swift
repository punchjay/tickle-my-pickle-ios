import XCTest

/// Runs the app with the device in dark mode. The app's design is a fixed light
/// palette, so dark mode should change nothing visible -- but system-drawn
/// pieces (like a text field's default placeholder) do adapt, and that's how the
/// search placeholder once turned light gray on the white pill and vanished.
/// Uses the same `-uiTestStubData` stubs as `LandingFlowUITests`.
@MainActor
final class DarkModeUITests: XCTestCase {
  private var originalAppearance: XCUIDevice.Appearance = .light

  override func setUp() {
    continueAfterFailure = false
    originalAppearance = XCUIDevice.shared.appearance
    XCUIDevice.shared.appearance = .dark
  }

  override func tearDown() {
    // The simulator keeps its appearance across runs; put it back so other
    // tests (and the person watching) aren't left in dark mode.
    XCUIDevice.shared.appearance = originalAppearance
  }

  private func launchStubbedApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-uiTestStubData"]
    app.launch()
    return app
  }

  /// Regression test for the vanishing placeholder: measure the contrast
  /// between the placeholder text and the pill behind it, straight from a
  /// screenshot. The fixed caramel placeholder measures about 4.5:1; the old
  /// adaptive one was close to 1:1 in dark mode.
  func testSearchPlaceholderIsReadableInDarkMode() throws {
    let app = launchStubbedApp()

    let searchField = app.textFields.firstMatch
    XCTAssertTrue(
      searchField.waitForExistence(timeout: 5), "Landing search field should be present")
    XCTAssertEqual(searchField.placeholderValue, "Search City, ZIP, or Hood")

    let screenshot = XCUIScreen.main.screenshot()
    attach(screenshot, named: "dark-landing")

    let ratio = try XCTUnwrap(
      contrastRange(in: screenshot.image, region: searchField.frame, screen: app.frame),
      "Couldn't read the search field's pixels from the screenshot")
    XCTAssertGreaterThanOrEqual(
      ratio, 3.0, "Placeholder text measures only \(ratio):1 against the pill in dark mode")
  }

  /// The core journey still works in dark mode: search, see results, save a
  /// court, and find it on the Saved tab.
  func testSearchAndSaveFlowInDarkMode() {
    let app = launchStubbedApp()

    let searchField = app.textFields.firstMatch
    XCTAssertTrue(
      searchField.waitForExistence(timeout: 5), "Landing search field should be present")
    searchField.tap()
    searchField.typeText("Seattle\n")

    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Results list should render in dark mode")

    app.buttons["Save court"].firstMatch.tap()
    let savedTab = app.buttons["Saved"].firstMatch
    XCTAssertTrue(savedTab.waitForExistence(timeout: 5), "Saved tab should be present")
    savedTab.tap()
    XCTAssertTrue(
      app.staticTexts["Ballard Community Court"].waitForExistence(timeout: 5),
      "Saved tab should list the saved court in dark mode")
    attach(XCUIScreen.main.screenshot(), named: "dark-saved")
  }

  // MARK: - Helpers

  private func attach(_ screenshot: XCUIScreenshot, named name: String) {
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// WCAG contrast ratio between the lightest and darkest pixels inside
  /// `region` (in points). For a text field showing only its placeholder, that's
  /// the pill background against the core of the text glyphs.
  private func contrastRange(in image: UIImage, region: CGRect, screen: CGRect) -> Double? {
    guard let cgImage = image.cgImage, screen.width > 0 else { return nil }
    let scale = CGFloat(cgImage.width) / screen.width
    let pixelRect = CGRect(
      x: region.minX * scale, y: region.minY * scale,
      width: region.width * scale, height: region.height * scale,
    ).integral
    guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }

    let width = cropped.width, height = cropped.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drew else { return nil }

    func channel(_ v: UInt8) -> Double {
      let c = Double(v) / 255
      return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    var darkest = 1.0, lightest = 0.0
    for i in stride(from: 0, to: pixels.count, by: 4) {
      let l = 0.2126 * channel(pixels[i]) + 0.7152 * channel(pixels[i + 1])
        + 0.0722 * channel(pixels[i + 2])
      darkest = min(darkest, l)
      lightest = max(lightest, l)
    }
    return (lightest + 0.05) / (darkest + 0.05)
  }
}
