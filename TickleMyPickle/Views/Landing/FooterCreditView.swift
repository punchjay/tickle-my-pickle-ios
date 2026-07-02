import SwiftUI

struct FooterCreditView: View {
  var body: some View {
    // Build the string manually rather than interpolating the Int directly
    // into Text("...") -- SwiftUI's LocalizedStringKey interpolation applies
    // locale number-grouping to raw Int/Double interpolations (e.g. "2,026").
    let year = String(Calendar.current.component(.year, from: .now))
    Text("© \(year) \(AppCopy.App.wordmark)")
      .font(AppFont.body(13))
      .foregroundStyle(Semantic.textMuted)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Semantic.card)
      .overlay(Capsule().stroke(Semantic.borderSoft, lineWidth: 1))
      .clipShape(Capsule())
      .cardShadow()
  }
}
