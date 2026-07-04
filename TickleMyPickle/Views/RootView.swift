import SwiftUI

/// Root layout, ported from the original app's `index.tsx`: pre-search shows
/// a centered search card over an animated backdrop; post-search splits the
/// screen vertically into a MapKit map (slightly taller) on top and a results
/// list below.
struct RootView: View {
  @State private var viewModel = PickleballMapViewModel()
  @State private var favoritesStore = FavoritesStore()

  private var hasResults: Bool { !viewModel.courts.isEmpty }

  var body: some View {
    Group {
      if hasResults {
        resultsLayout
      } else {
        landingLayout
      }
    }
    .background(Semantic.bg)
  }

  private var landingLayout: some View {
    ZStack {
      StripedBackdropView()
        .ignoresSafeArea()

      VStack(spacing: 8) {
        HeaderCardView()
        searchColumn
      }
      .padding(.horizontal, 24)
      .frame(maxWidth: 420)

      VStack {
        Spacer()
        FooterCreditView()
          .padding(.bottom, 16)
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
          searchColumn
            .frame(maxWidth: 420)
            .padding(.horizontal, 12)
            .padding(.top, 8)
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

  private var searchColumn: some View {
    VStack(spacing: 8) {
      SearchPillView(
        loading: viewModel.loading,
        disabled: !viewModel.hasApiKey,
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
