import SwiftUI

struct HeaderCardView: View {
  var body: some View {
    VStack(spacing: 2) {
      Text(AppCopy.App.wordmark)
        .font(AppFont.accent(38))
        .foregroundStyle(Palette.courtBlue)
      Text(AppCopy.App.tagline)
        .font(AppFont.body(16))
        .foregroundStyle(Semantic.textMuted)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Semantic.card)
    .overlay(RoundedRectangle(cornerRadius: Radii.md).stroke(Semantic.borderSoft, lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: Radii.md))
    .cardShadow()
  }
}
