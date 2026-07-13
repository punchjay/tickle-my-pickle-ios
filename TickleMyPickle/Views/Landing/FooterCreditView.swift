import SwiftUI

/// Floating credit pill, ported from the original app's `Footer`:
/// "© {year} {wordmark} | Get in touch {GitHub icon}", with the contact
/// mailto link and GitHub profile link in the theme link color.
struct FooterCreditView: View {
  var body: some View {
    // Build the string manually rather than interpolating the Int directly
    // into Text("...") -- SwiftUI's LocalizedStringKey interpolation applies
    // locale number-grouping to raw Int/Double interpolations (e.g. "2,026").
    let year = String(Calendar.current.component(.year, from: .now))
    HStack(spacing: 6) {
      Text("© \(year) \(AppCopy.Footer.credit) |")
      Link(AppCopy.Footer.contactLabel, destination: contactURL)
      Link(destination: URL(string: AppCopy.Footer.githubURL)!) {
        Image("github")
          .resizable()
          .frame(width: 16, height: 16)
      }
      .accessibilityLabel(AppCopy.Footer.githubLabel)
    }
    .font(AppFont.body(13))
    .foregroundStyle(Semantic.textMuted)
    .tint(Semantic.link)
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
    .background(Semantic.card)
    .overlay(Capsule().stroke(Semantic.borderSoft, lineWidth: 1))
    .clipShape(Capsule())
    .cardShadow()
  }

  private var contactURL: URL {
    URL(string: "mailto:\(AppCopy.Footer.email)?subject=\(AppCopy.Footer.emailSubject)")!
  }
}
