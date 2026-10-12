import SwiftUI

/// Root layout, ported from the original app's `index.tsx`: pre-search shows
/// a centered search card over an animated backdrop; post-search splits the
/// screen vertically into a MapKit map (slightly taller) on top and a results
/// list below.
struct RootView: View {
  @State private var viewModel = PickleballMapViewModel.forLaunch()
  @State private var favoritesStore = FavoritesStore()

  private var hasResults: Bool { !viewModel.courts.isEmpty }

  var body: some View {
    GeometryReader { proxy in
      Group {
        if hasResults {
          resultsLayout
        } else {
          landingLayout
        }
      }
      .background(Semantic.bg)
      // Translucent scrim over the status bar / top menu bar so its content
      // stays legible over the backdrop (landing) and the map (results).
      .overlay(alignment: .top) {
        Semantic.bg.opacity(0.75)
          .frame(height: proxy.safeAreaInsets.top)
          .frame(maxWidth: .infinity)
          .ignoresSafeArea(edges: .top)
      }
    }
  }

  private var landingLayout: some View {
    GeometryReader { geo in
      ZStack {
        StripedBackdropView()
          .ignoresSafeArea()

        // The search field takes focus on launch, so the keyboard slides up
        // and the pill rides just above it; the header card stays centered
        // in the space left over. Width min(400, screen - 32).
        VStack(spacing: 0) {
          Spacer(minLength: 8)
          HeaderCardView()
            // Keep the card at its natural height; between two Spacers it can
            // be squeezed a hair, which clips the wordmark's glyphs.
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 8)
          searchColumn(autoFocus: true)
            .padding(.bottom, 12)
        }
        .frame(width: min(400, geo.size.width - 32))
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var resultsLayout: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ZStack(alignment: .top) {
          CourtMapView(
            courts: viewModel.courts,
            selectedId: viewModel.selectedId,
            center: viewModel.center,
            zoom: viewModel.zoom,
            onSelectCourt: viewModel.handleCourtSelect,
          )
          searchColumn()
            .frame(maxWidth: 420)
            .padding(.horizontal, 12)
            // Sits 5pt lower than it used to, clearing the status-bar scrim.
            .padding(.top, 13)
        }
        // Matches the original app's MapArea flex 1.1 / ListArea flex 1 ratio.
        .frame(height: geometry.size.height * (1.1 / 2.1))

        CourtListView(
          courts: viewModel.courts,
          selectedCourt: viewModel.selectedCourt,
          favorites: favoritesStore.favorites,
          onSelect: viewModel.handleCourtSelect,
          isFavorite: favoritesStore.isFavorite,
          onToggleFavorite: favoritesStore.toggleFavorite,
        )
        .id(viewModel.searchSeq)
        .frame(height: geometry.size.height * (1.0 / 2.1))
      }
    }
  }

  private func searchColumn(autoFocus: Bool = false) -> some View {
    VStack(spacing: 8) {
      SearchPillView(
        loading: viewModel.loading,
        disabled: !viewModel.hasApiKey,
        autoFocus: autoFocus,
        onSearch: { query in Task { await viewModel.handleSearch(query: query) } },
        onGeolocate: { Task { await viewModel.handleGeolocate() } },
      )
      if let error = viewModel.error {
        errorBanner(error)
      }
    }
  }

  private func errorBanner(_ message: String) -> some View {
    Text(message)
      .font(AppFont.body(13))
      .foregroundStyle(Semantic.text)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Semantic.card)
      .overlay(Rectangle().fill(Semantic.closed).frame(width: 4), alignment: .leading)
      .clipShape(RoundedRectangle(cornerRadius: Radii.sm))
      .cardShadow()
  }
}
