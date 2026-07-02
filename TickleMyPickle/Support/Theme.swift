import SwiftUI

extension Color {
  /// `#RRGGBB` hex initializer -- the palette below is specified as hex to
  /// match the original design tokens (a Dinkly mood board) exactly, rather
  /// than approximating with named SwiftUI colors.
  init(hex: String) {
    var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hex = hex.replacingOccurrences(of: "#", with: "")
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    let r = Double((value >> 16) & 0xFF) / 255
    let g = Double((value >> 8) & 0xFF) / 255
    let b = Double(value & 0xFF) / 255
    self.init(red: r, green: g, blue: b)
  }
}

enum Palette {
  static let ivory = Color(hex: "#EFE7D3") // canvas / page background
  static let surface = Color(hex: "#FBF6EA") // cards, panels
  static let terracotta = Color(hex: "#E07C53") // primary action (grip/border)
  static let terracottaDark = Color(hex: "#C4633D") // primary hover/active
  static let marigold = Color(hex: "#E29A33") // ratings, secondary accent
  static let tomato = Color(hex: "#C8442B") // alerts / strong accent
  static let courtBlue = Color(hex: "#2E5A86") // links, map UI
  static let midnight = Color(hex: "#1E2D49") // primary text / dark buttons
  static let caramel = Color(hex: "#9C6B3C") // muted labels, hairlines
  static let lime = Color(hex: "#CFE24A") // "free" / open pop
  static let sunshine = Color(hex: "#F4D62E") // "lighted" / highlight pop
}

enum Semantic {
  static let bg = Palette.ivory
  static let card = Palette.surface
  static let text = Palette.midnight
  static let textMuted = Palette.caramel
  static let primary = Palette.terracotta
  static let primaryHover = Palette.terracottaDark
  static let link = Palette.courtBlue
  static let border = Color(hex: "#DCCFB0")
  static let borderSoft = Color(hex: "#E2D6BC")
  static let open = Color(hex: "#3B6D11") // "open now" status
  static let closed = Palette.tomato // "closed" status
}

enum Radii {
  static let sm: CGFloat = 8
  static let md: CGFloat = 12
  static let pill: CGFloat = 999
}

/// Mirrors the original web/RN card shadow: `0 2px 12px rgba(30,45,73,0.18)`.
struct CardShadow: ViewModifier {
  func body(content: Content) -> some View {
    content.shadow(color: Palette.midnight.opacity(0.18), radius: 12, x: 0, y: 2)
  }
}

extension View {
  func cardShadow() -> some View {
    modifier(CardShadow())
  }
}
