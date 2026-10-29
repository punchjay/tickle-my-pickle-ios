import SwiftUI

/// Numbered teardrop pin, matching the web app's Google Maps `PinElement`:
/// the number sits in the round head and the tip marks the court, so the
/// annotation is anchored at `.bottom` (see CourtMapView).
struct CourtPinView: View {
  let number: Int
  let selected: Bool

  // The number uses the footnote text style (13pt by default), and the head
  // scales with it so larger numbers still fit.
  @ScaledMetric(relativeTo: .footnote) private var baseWidth: CGFloat = 28

  // Same 1.3x bump the web app gives the selected pin.
  private var width: CGFloat { selected ? baseWidth * 1.3 : baseWidth }
  // Google's pin is 26 x 37.
  private var height: CGFloat { width * 37 / 26 }

  var body: some View {
    ZStack(alignment: .top) {
      TeardropShape()
        .fill(selected ? Palette.midnight : Palette.terracottaDeep)
        .overlay(
          TeardropShape().stroke(selected ? Palette.midnight : Palette.terracottaDeep, lineWidth: 2),
        )
      Text("\(number)")
        .font(.footnote.bold())
        .foregroundStyle(.white)
        .frame(width: width, height: width)
    }
    .frame(width: width, height: height)
  }
}

/// A circle the full width of the rect, tapering to a point at bottom center.
private struct TeardropShape: Shape {
  func path(in rect: CGRect) -> Path {
    let radius = rect.width / 2
    let center = CGPoint(x: rect.midX, y: rect.minY + radius)
    let tip = CGPoint(x: rect.midX, y: rect.maxY)
    // The sides are tangent to the circle; the tangent points sit this far
    // either side of straight down.
    let spread = Angle(radians: acos(radius / (tip.y - center.y)))

    var path = Path()
    path.move(to: tip)
    path.addArc(
      center: center, radius: radius,
      startAngle: .degrees(90) + spread, endAngle: .degrees(450) - spread,
      clockwise: false)
    path.closeSubpath()
    return path
  }
}
