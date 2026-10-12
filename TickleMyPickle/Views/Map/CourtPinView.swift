import SwiftUI

/// Numbered circular pin, ported from the original app's map marker styling.
struct CourtPinView: View {
  let number: Int
  let selected: Bool

  // The number uses the footnote text style (13pt by default), and the circle
  // scales with it so larger numbers still fit.
  @ScaledMetric(relativeTo: .footnote) private var baseSize: CGFloat = 28

  private var size: CGFloat { selected ? baseSize + 6 : baseSize }

  var body: some View {
    ZStack {
      Circle()
        .fill(selected ? Palette.midnight : Palette.terracotta)
        .overlay(
          Circle().stroke(selected ? Palette.midnight : Palette.terracottaDark, lineWidth: 2),
        )
      Text("\(number)")
        .font(.footnote.bold())
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}
