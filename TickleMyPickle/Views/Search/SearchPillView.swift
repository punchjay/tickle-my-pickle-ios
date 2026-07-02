import SwiftUI

/// Search pill: leading icon button (submit), a text field, a divider, and a
/// trailing "Near me" button. Ported from the original app's `LocationInput`.
struct SearchPillView: View {
  let loading: Bool
  let disabled: Bool
  let onSearch: (String) -> Void
  let onGeolocate: () -> Void

  @State private var query = ""

  private var blocked: Bool { disabled || loading }

  var body: some View {
    HStack(spacing: 4) {
      HStack(spacing: 8) {
        Button(action: submit) {
          if loading {
            ProgressView()
              .tint(Semantic.primary)
          } else {
            Image(systemName: "magnifyingglass")
              .foregroundStyle(Semantic.primary)
          }
        }
        .frame(width: 28, height: 28)
        .disabled(blocked)
        .accessibilityLabel(AppCopy.Search.submitLabel)

        TextField(AppCopy.Search.placeholder, text: $query)
          .font(AppFont.body(16))
          .foregroundStyle(Semantic.text)
          .disabled(blocked)
          .submitLabel(.search)
          .onSubmit(submit)
          .accessibilityLabel(AppCopy.Search.inputLabel)
      }

      Rectangle()
        .fill(Semantic.border)
        .frame(width: 1, height: 22)

      Button {
        // Clear the typed location when searching by current position, so the
        // input doesn't keep showing a stale query that no longer matches.
        query = ""
        onGeolocate()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "location.fill")
          Text(AppCopy.Search.nearMe)
            .font(AppFont.bodyMedium(14))
        }
        .foregroundStyle(Semantic.link)
      }
      .disabled(blocked)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
    .padding(.leading, 12)
    .padding(.trailing, 10)
    .padding(.vertical, 4)
    .background(Color.white)
    .clipShape(Capsule())
    .overlay(Capsule().stroke(Semantic.borderSoft, lineWidth: 1))
    .cardShadow()
  }

  private func submit() {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSearch(trimmed)
  }
}
