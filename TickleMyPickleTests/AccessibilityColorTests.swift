import SwiftUI
import XCTest
@testable import TickleMyPickle

/// WCAG AA contrast for every foreground/background pairing the views actually
/// draw. Each case names the view that uses it, so a palette tweak that breaks
/// legibility points straight at the screen it hurts.
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
      Pairing("Tagline and addresses (HeaderCardView, CourtRowView)", Semantic.textMuted, on: Semantic.card),
      Pairing(
        "Search icon (SearchPillView)", Semantic.primaryHover, on: .white,
        minimum: WCAG.largeTextAndUIMinimum),
      Pairing(
        "Filled star (CourtRowView)", Semantic.primaryHover, on: Semantic.card,
        minimum: WCAG.largeTextAndUIMinimum),
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
      Pairing("Row number (CourtRowView)", .white, on: Palette.terracottaDeep),
      Pairing("Pin number (CourtPinView)", .white, on: Palette.terracottaDeep),
      Pairing("Star rating (CourtRowView)", Palette.marigoldDeep, on: Semantic.card),
      Pairing("Selected tab (CourtListView)", Semantic.text, on: Palette.ivory),
      // The tab's own background is clear, so the list's shows through.
      Pairing(
        "Unselected tab (CourtListView, 0.75 opacity)", Semantic.text, on: Semantic.bg,
        opacity: 0.75, over: Semantic.bg),
    ]
    for pairing in pairings {
      pairing.check()
    }
  }
}
