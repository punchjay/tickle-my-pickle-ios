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
        tabButton(.saved, label: "\(AppCopy.CourtList.savedTab) (\(favorites.count))")
      }
      .padding(.horizontal, 8)
      .padding(.top, 8)

      if tab == .saved && favorites.isEmpty {
        Text(AppCopy.CourtList.emptySaved)
          .font(AppFont.body(14))
          .foregroundStyle(Semantic.textMuted)
          .multilineTextAlignment(.center)
          .padding(24)
          .frame(maxWidth: .infinity)
      } else {
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
    }
    .background(Semantic.bg)
  }

  private func tabButton(_ target: Tab, label: String) -> some View {
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
    }
    .buttonStyle(.plain)
  }
}
