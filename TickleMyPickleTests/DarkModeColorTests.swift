import SwiftUI
import UIKit
import XCTest
@testable import TickleMyPickle

/// The app's surfaces are a fixed light palette (the search pill is always
/// white, cards are always cream) and don't adapt to dark mode. Anything drawn
/// on them therefore has to stay a fixed color too: a system color that adapts
/// turns light in dark mode and vanishes, which is exactly how the search
/// placeholder broke. These tests resolve colors under a dark trait collection
/// to catch that.
final class DarkModeColorTests: XCTestCase {
  private let light = UITraitCollection(userInterfaceStyle: .light)
  private let dark = UITraitCollection(userInterfaceStyle: .dark)

  func testPaletteColorsDoNotChangeInDarkMode() {
    let colors: [(String, Color)] = [
      ("bg", Semantic.bg),
      ("card", Semantic.card),
      ("text", Semantic.text),
      ("textMuted", Semantic.textMuted),
      ("primary", Semantic.primary),
      ("link", Semantic.link),
      ("border", Semantic.border),
      ("open", Semantic.open),
      ("closed", Semantic.closed),
    ]
    for (name, color) in colors {
      XCTAssertEqual(
        WCAG.rgb(color, in: light), WCAG.rgb(color, in: dark),
        "Semantic.\(name) should be the same in light and dark mode")
    }
  }

  func testSearchPlaceholderIsReadableOnTheWhitePillInDarkMode() {
    let ratio = WCAG.contrast(WCAG.rgb(Semantic.textMuted, in: dark), WCAG.rgb(.white, in: dark))
    XCTAssertGreaterThanOrEqual(
      ratio, WCAG.textMinimum, "Placeholder contrast on the white pill is \(ratio):1")
  }

  func testTypedSearchTextIsReadableOnTheWhitePillInDarkMode() {
    let ratio = WCAG.contrast(WCAG.rgb(Semantic.text, in: dark), WCAG.rgb(.white, in: dark))
    XCTAssertGreaterThanOrEqual(
      ratio, WCAG.textMinimum, "Typed text contrast on the white pill is \(ratio):1")
  }
}
