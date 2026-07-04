import XCTest

@testable import TickleMyPickle

@MainActor
final class FavoritesStoreTests: XCTestCase {
  private static let storageKey = "tmp:favorites"

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: Self.storageKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: Self.storageKey)
    super.tearDown()
  }

  private func court(_ id: String) -> Court {
    Court(
      id: id, name: "Court \(id)", address: "", rating: nil, userRatingCount: nil,
      isOpen: nil, types: nil, location: LatLng(lat: 0, lng: 0),
    )
  }

  func testStartsEmptyWithNoStoredData() {
    let store = FavoritesStore()
    XCTAssertTrue(store.favorites.isEmpty)
    XCTAssertFalse(store.isFavorite("1"))
  }

  func testTogglingAddsThenRemoves() {
    let store = FavoritesStore()
    let court = court("1")

    store.toggleFavorite(court)
    XCTAssertEqual(store.favorites.map(\.id), ["1"])
    XCTAssertTrue(store.isFavorite("1"))

    store.toggleFavorite(court)
    XCTAssertTrue(store.favorites.isEmpty)
    XCTAssertFalse(store.isFavorite("1"))
  }

  func testFavoritesPersistToAFreshInstance() {
    let store = FavoritesStore()
    store.toggleFavorite(court("1"))
    store.toggleFavorite(court("2"))

    // A new store reads straight from UserDefaults in init.
    let reloaded = FavoritesStore()
    XCTAssertEqual(reloaded.favorites.map(\.id), ["1", "2"])
    XCTAssertTrue(reloaded.isFavorite("2"))
  }
}
