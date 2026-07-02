import SwiftUI

/// Retro diagonal-stripe backdrop, ported conceptually from the original
/// app's `stripedBackdrop` CSS mixin (a `repeating-linear-gradient` at 110°
/// that drifts on a 12s loop). SwiftUI has no CSS keyframes, so this redraws
/// the stripes every frame via `TimelineView(.animation)` + `Canvas`, rotating
/// and translating an oversized band of colors so the drift always loops
/// seamlessly and never reveals a screen corner.
struct StripedBackdropView: View {
  private let bandColors: [Color] = [
    Palette.marigold, Palette.tomato, Palette.courtBlue, Palette.midnight, Palette.ivory,
  ]
  private let bandWidth: CGFloat = 36
  private let angleDegrees: Double = 20
  private let periodSeconds: Double = 12

  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let period = bandWidth * CGFloat(bandColors.count)
        let side = max(size.width, size.height) * 1.8
        let bandCount = Int((side / bandWidth).rounded(.up)) + 10

        let elapsed = timeline.date.timeIntervalSinceReferenceDate
        let progress = elapsed.truncatingRemainder(dividingBy: periodSeconds) / periodSeconds
        let offset = CGFloat(progress) * period

        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: .degrees(angleDegrees))
        context.translateBy(x: -side / 2 - offset, y: -side / 2)

        for i in 0..<bandCount {
          let rect = CGRect(x: CGFloat(i) * bandWidth, y: 0, width: bandWidth, height: side)
          context.fill(Path(rect), with: .color(bandColors[i % bandColors.count]))
        }
      }
    }
    .overlay(Palette.ivory.opacity(0.1))
    .clipped()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
