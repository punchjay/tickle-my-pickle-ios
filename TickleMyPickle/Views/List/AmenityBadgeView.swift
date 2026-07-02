import SwiftUI

struct AmenityBadgeView: View {
  let kind: AmenityKind

  /// Per-kind colors come straight from the theme: court-blue for Indoor
  /// (dark, so light text), lime for Outdoor/Free and sunshine for Lighted
  /// (both light, so dark text).
  private var colors: (bg: Color, fg: Color) {
    switch kind {
    case .indoor: return (Palette.courtBlue, Semantic.card)
    case .outdoor, .free: return (Palette.lime, Palette.midnight)
    case .lighted: return (Palette.sunshine, Palette.midnight)
    }
  }

  var body: some View {
    Text(AppCopy.Amenities.label(for: kind))
      .font(AppFont.bodyBold(11))
      .foregroundStyle(colors.fg)
      .padding(.horizontal, 7)
      .padding(.vertical, 1)
      .background(colors.bg)
      .clipShape(Capsule())
  }
}
