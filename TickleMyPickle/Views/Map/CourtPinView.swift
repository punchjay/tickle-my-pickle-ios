import SwiftUI

/// Numbered circular pin, ported from the original app's map marker styling.
struct CourtPinView: View {
  let number: Int
  let selected: Bool

  private var size: CGFloat { selected ? 34 : 28 }

  var body: some View {
    ZStack {
      Circle()
        .fill(selected ? Palette.midnight : Palette.terracotta)
        .overlay(
          Circle().stroke(selected ? Palette.midnight : Palette.terracottaDark, lineWidth: 2),
        )
      Text("\(number)")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}
