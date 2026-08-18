import SwiftUI

/// Tabs (Nearby / Saved) + results list. Ported from the original app's
/// `CourtList`.
struct CourtListView: View {
  let courts: [Court]
  let selectedCourt: Court?
  let favorites: [Court]
  let onSelect: (Court) -> Void
  let isFavorite: (String) -> Bool
  let onToggleFavorite: (Court) -> Void

  private enum Tab {
    case nearby
    case saved
  }

  @State private var tab: Tab = .nearby

  private var rows: [Court] {
    tab == .nearby ? courts : favorites
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        tabButton(.nearby, label: "\(AppCopy.CourtList.nearbyTab) (\(courts.count))")
        tabButton(
          .saved,
          label: "\(AppCopy.CourtList.savedTab) (\(favorites.count))",
          // Nothing to show with no saves, so the tab is a dead end — dim it
          // and let the star on each row be the way in.
          disabled: favorites.isEmpty,
        )
      }
      .padding(.horizontal, 8)
      .padding(.top, 8)

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, court in
              CourtRowView(
                court: court,
                number: tab == .nearby ? index + 1 : nil,
                selected: court.id == selectedCourt?.id,
                isFavorite: isFavorite(court.id),
                onSelect: { onSelect(court) },
                onToggleFavorite: { onToggleFavorite(court) },
              )
              .id(court.id)
            }
          }
          .padding(12)
        }
        // Scroll the selected court into view (Nearby tab only), mirroring
        // the original app's scrollIntoView behavior.
        .onChange(of: selectedCourt?.id) { _, newValue in
          guard tab == .nearby, let newValue else { return }
          withAnimation {
            proxy.scrollTo(newValue, anchor: .center)
          }
        }
      }
    }
    // Unstarring the last saved court from inside the Saved tab would otherwise
    // strand us on a tab that can no longer be tapped back into.
    .onChange(of: favorites.isEmpty) { _, isEmpty in
      if isEmpty { tab = .nearby }
    }
    .background(Semantic.bg)
  }

  private func tabButton(_ target: Tab, label: String, disabled: Bool = false) -> some View {
    Button {
      tab = target
    } label: {
      Text(label)
        .font(AppFont.bodyBold(13))
        .foregroundStyle(tab == target ? Semantic.text : Semantic.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tab == target ? Palette.ivory : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
        // `.plain` + an explicit foregroundStyle suppresses SwiftUI's automatic
        // dimming, so the disabled look has to be spelled out.
        .opacity(disabled ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    // VoiceOver otherwise announces the dimmed tab with no reason for it.
    .accessibilityHint(disabled ? AppCopy.CourtList.emptySaved : "")
  }
}
