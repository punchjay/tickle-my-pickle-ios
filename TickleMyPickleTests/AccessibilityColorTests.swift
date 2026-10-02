import SwiftUI
import XCTest
@testable import TickleMyPickle

/// WCAG AA contrast for every foreground/background pairing the views actually
/// draw. Each case names the view that uses it, so a palette tweak that breaks
/// legibility points straight at the screen it hurts.
///
/// Pairings that fail today are listed in `testKnownLowContrastPairings`
/// under `XCTExpectFailure`: the suite stays green, and each one turns into a
/// failure ("expected failure but none occurred") as soon as it's fixed, so
/// it can be moved up into the passing list.
final class AccessibilityColorTests: XCTestCase {
  private struct Pairing {
    let use: String
    let fg: WCAG.RGB
    let bg: WCAG.RGB
    let minimum: Double

    init(_ use: String, _ fg: Color, on bg: Color, minimum: Double = WCAG.textMinimum) {
      self.use = use
      self.fg = WCAG.rgb(fg)
      self.bg = WCAG.rgb(bg)
      self.minimum = minimum
    }

    /// For views drawn with `.opacity(_:)`: the label and its background fade
    /// together over whatever sits behind the view.
    init(_ use: String, _ fg: Color, on bg: Color, opacity: Double, over backdrop: Color) {
      let backdrop = WCAG.rgb(backdrop)
      self.use = use
      self.fg = WCAG.composite(WCAG.rgb(fg), opacity: opacity, over: backdrop)
      self.bg = WCAG.composite(WCAG.rgb(bg), opacity: opacity, over: backdrop)
      self.minimum = WCAG.textMinimum
    }

    func check(file: StaticString = #filePath, line: UInt = #line) {
      let ratio = WCAG.contrast(fg, bg)
      XCTAssertGreaterThanOrEqual(
        ratio, minimum,
        "\(use): \(String(format: "%.2f", ratio)):1, needs \(minimum):1", file: file, line: line)
    }
  }

  func testTextAndIconsMeetAAContrast() {
    let pairings = [
      Pairing("Body text on cards (CourtRowView, error banner)", Semantic.text, on: Semantic.card),
      Pairing("Typed search text (SearchPillView)", Semantic.text, on: .white),
      Pairing("Search placeholder (SearchPillView)", Semantic.textMuted, on: .white),
      Pairing("\"Near me\" (SearchPillView)", Semantic.link, on: .white),
      Pairing("\"Directions\" link (CourtRowView)", Semantic.link, on: Semantic.card),
      Pairing("\"Open now\" (CourtRowView)", Semantic.open, on: Semantic.card),
      Pairing("\"Closed\" (CourtRowView)", Semantic.closed, on: Semantic.card),
      Pairing("Wordmark (HeaderCardView)", Palette.courtBlue, on: Semantic.card),
      Pairing("Selected row number (CourtRowView)", .white, on: Palette.midnight),
      Pairing("Indoor badge (AmenityBadgeView)", Semantic.card, on: Palette.courtBlue),
      Pairing("Outdoor/Free badge (AmenityBadgeView)", Palette.midnight, on: Palette.lime),
      Pairing("Lighted badge (AmenityBadgeView)", Palette.midnight, on: Palette.sunshine),
      Pairing("Selected pin number (CourtPinView)", .white, on: Palette.midnight),
      Pairing(
        "Selected tab (CourtListView, 0.8 opacity)", Semantic.text, on: Palette.ivory,
        opacity: 0.8, over: Semantic.bg),
    ]
    for pairing in pairings {
      pairing.check()
    }
  }

  /// Each fails AA today. Fix the color, then move the pairing up into
  /// `testTextAndIconsMeetAAContrast`.
  func testKnownLowContrastPairings() {
    let known = [
      // 4.25:1 -- needs a slightly darker caramel for text on cream.
      Pairing("Tagline and addresses (HeaderCardView, CourtRowView)", Semantic.textMuted, on: Semantic.card),
      // 2.19:1
      Pairing("Star rating (CourtRowView)", Palette.marigold, on: Semantic.card),
      // 2.93:1 -- 13pt bold isn't large text, so it needs 4.5.
      Pairing("Row number (CourtRowView)", .white, on: Palette.terracotta),
      Pairing("Pin number (CourtPinView)", .white, on: Palette.terracotta),
      // 2.74:1. The tab's own background is clear, so the list's shows through.
      Pairing(
        "Unselected tab (CourtListView, 0.8 opacity)", Semantic.textMuted, on: Semantic.bg,
        opacity: 0.8, over: Semantic.bg),
      // 2.93:1 -- icons only need 3:1, and this just misses.
      Pairing(
        "Search icon (SearchPillView)", Semantic.primary, on: .white,
        minimum: WCAG.largeTextAndUIMinimum),
      // 2.71:1
      Pairing(
        "Filled star (CourtRowView)", Semantic.primary, on: Semantic.card,
        minimum: WCAG.largeTextAndUIMinimum),
    ]
    for pairing in known {
      XCTExpectFailure("Known low contrast: \(pairing.use)") {
        pairing.check()
      }
    }
  }
}
