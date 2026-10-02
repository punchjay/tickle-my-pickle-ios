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

  /// WCAG AA minimum for body text.
  private let minimumTextContrast = 4.5

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
        rgb(color, in: light), rgb(color, in: dark),
        "Semantic.\(name) should be the same in light and dark mode")
    }
  }

  func testSearchPlaceholderIsReadableOnTheWhitePillInDarkMode() {
    let ratio = contrast(rgb(Semantic.textMuted, in: dark), rgb(.white, in: dark))
    XCTAssertGreaterThanOrEqual(
      ratio, minimumTextContrast, "Placeholder contrast on the white pill is \(ratio):1")
  }

  func testTypedSearchTextIsReadableOnTheWhitePillInDarkMode() {
    let ratio = contrast(rgb(Semantic.text, in: dark), rgb(.white, in: dark))
    XCTAssertGreaterThanOrEqual(
      ratio, minimumTextContrast, "Typed text contrast on the white pill is \(ratio):1")
  }

  // MARK: - Helpers

  private struct RGB: Equatable {
    let r: Double
    let g: Double
    let b: Double
  }

  /// Resolves a SwiftUI color for the given appearance and rounds to 8-bit
  /// steps, so float noise can't fail an equality check.
  private func rgb(_ color: Color, in traits: UITraitCollection) -> RGB {
    let resolved = UIColor(color).resolvedColor(with: traits)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
    func step(_ v: CGFloat) -> Double { (Double(v) * 255).rounded() / 255 }
    return RGB(r: step(r), g: step(g), b: step(b))
  }

  /// WCAG 2.x contrast ratio between two opaque sRGB colors.
  private func contrast(_ a: RGB, _ b: RGB) -> Double {
    func channel(_ c: Double) -> Double {
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    func luminance(_ c: RGB) -> Double {
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
    let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
    return (hi + 0.05) / (lo + 0.05)
  }
}
