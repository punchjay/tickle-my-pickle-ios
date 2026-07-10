import Foundation

/// Favorites persist across launches, ported from the original app's
/// `useFavorites.ts`. UserDefaults is synchronous (unlike the RN app's
/// AsyncStorage), so the list loads directly in `init` rather than an async
/// hydration effect.
@Observable
@MainActor
final class FavoritesStore {
  private static let storageKey = "tmp:favorites"

  private(set) var favorites: [Court] = []

  init() {
    #if DEBUG
      // Under UI tests, start from a clean slate: favorites persist in
      // UserDefaults across launches, so a previous run's saves would
      // otherwise leak into this one and break determinism.
      if ProcessInfo.processInfo.arguments.contains(uiTestStubArgument) {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
      }
    #endif
    favorites = Self.readFavorites()
  }

  private static func readFavorites() -> [Court] {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
    return (try? JSONDecoder().decode([Court].self, from: data)) ?? []
  }

  private func writeFavorites() {
    guard let data = try? JSONEncoder().encode(favorites) else { return }
    UserDefaults.standard.set(data, forKey: Self.storageKey)
  }

  func isFavorite(_ id: String) -> Bool {
    favorites.contains { $0.id == id }
  }

  func toggleFavorite(_ court: Court) {
    if let index = favorites.firstIndex(where: { $0.id == court.id }) {
      favorites.remove(at: index)
    } else {
      favorites.append(court)
    }
    writeFavorites()
  }
}
