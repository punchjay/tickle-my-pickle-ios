import CoreLocation
import XCTest

@testable import TickleMyPickle

/// Stub `PlacesProviding` that returns canned results and records the inputs it
/// was called with, so the view model's search flow can be driven without any
/// network. `@unchecked Sendable`: mutated only from the serial, awaited calls
/// the MainActor view model makes in these tests.
final class FakePlacesProvider: PlacesProviding, @unchecked Sendable {
  var geocodeResult: Result<LatLng?, Error>
  var searchResult: Result<[Court], Error>
  private(set) var geocodeQueries: [String] = []
  private(set) var searchLocations: [LatLng] = []

  init(
    geocodeResult: Result<LatLng?, Error> = .success(LatLng(lat: 47.66, lng: -122.38)),
    searchResult: Result<[Court], Error> = .success([]),
  ) {
    self.geocodeResult = geocodeResult
    self.searchResult = searchResult
  }

  func geocode(query: String) async throws -> LatLng? {
    geocodeQueries.append(query)
    return try geocodeResult.get()
  }

  func searchCourts(near location: LatLng) async throws -> [Court] {
    searchLocations.append(location)
    return try searchResult.get()
  }
}

@MainActor
final class FakeLocationProvider: LocationProviding {
  var coordinate: CLLocationCoordinate2D?
  init(coordinate: CLLocationCoordinate2D?) { self.coordinate = coordinate }
  func requestOneShotLocation() async -> CLLocationCoordinate2D? { coordinate }
}

struct StubError: LocalizedError {
  let errorDescription: String?
}

@MainActor
final class PickleballMapViewModelTests: XCTestCase {
  private func court(_ id: String, lat: Double = 0, lng: Double = 0) -> Court {
    Court(
      id: id, name: "Court \(id)", address: "", rating: nil, userRatingCount: nil,
      isOpen: nil, types: nil, location: LatLng(lat: lat, lng: lng),
    )
  }

  private func makeViewModel(
    places: FakePlacesProvider = FakePlacesProvider(),
    location: CLLocationCoordinate2D? = nil,
    hasApiKey: Bool = true,
  ) -> PickleballMapViewModel {
    PickleballMapViewModel(
      places: places,
      locationProvider: FakeLocationProvider(coordinate: location),
      hasApiKey: hasApiKey,
    )
  }

  func testStartsFramedOnTheUSWithNoResults() {
    let vm = makeViewModel()
    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertNil(vm.selectedId)
    XCTAssertEqual(vm.center, PickleballMapViewModel.usCenter)
    XCTAssertEqual(vm.zoom, 4)
    XCTAssertFalse(vm.loading)
    XCTAssertNil(vm.error)
  }

  func testMissingApiKeyShowsErrorAndBlocksSearch() async {
    let places = FakePlacesProvider(searchResult: .success([court("1")]))
    let vm = makeViewModel(places: places, hasApiKey: false)
    XCTAssertEqual(vm.error, AppCopy.Errors.missingApiKey)

    await vm.handleSearch(query: "Ballard")

    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertTrue(places.geocodeQueries.isEmpty, "search must not touch the network without a key")
  }

  func testSuccessfulSearchPopulatesCourtsAndRecenters() async {
    let location = LatLng(lat: 47.66, lng: -122.38)
    let places = FakePlacesProvider(
      geocodeResult: .success(location),
      searchResult: .success([court("1", lat: 47.66, lng: -122.38), court("2")]),
    )
    let vm = makeViewModel(places: places)

    await vm.handleSearch(query: "Ballard")

    XCTAssertEqual(vm.courts.map(\.id), ["1", "2"])
    XCTAssertEqual(vm.center, location)
    XCTAssertEqual(vm.zoom, 12)
    XCTAssertEqual(vm.searchSeq, 1)
    XCTAssertNil(vm.selectedId)
    XCTAssertFalse(vm.loading)
    XCTAssertNil(vm.error)
    XCTAssertEqual(places.geocodeQueries, ["Ballard"])
    XCTAssertEqual(places.searchLocations, [location])
  }

  func testSearchWithUnknownLocationSurfacesNotFound() async {
    let places = FakePlacesProvider(geocodeResult: .success(nil))
    let vm = makeViewModel(places: places)

    await vm.handleSearch(query: "Nowhere")

    XCTAssertEqual(vm.error, AppCopy.Errors.locationNotFound)
    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertFalse(vm.loading)
    XCTAssertTrue(places.searchLocations.isEmpty, "no place search when geocoding finds nothing")
  }

  func testSearchWithNoCourtsSurfacesEmptyMessage() async {
    let places = FakePlacesProvider(searchResult: .success([]))
    let vm = makeViewModel(places: places)

    await vm.handleSearch(query: "Ballard")

    XCTAssertEqual(vm.error, AppCopy.Errors.noCourtsFound)
    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertEqual(vm.searchSeq, 0, "an empty result is not a new result set")
  }

  func testGeocodingErrorClearsResultsAndSurfacesReason() async {
    // Debug builds surface Google's own reason via localizedDescription.
    let places = FakePlacesProvider(
      geocodeResult: .failure(StubError(errorDescription: "Geocoding REQUEST_DENIED")),
    )
    let vm = makeViewModel(places: places)
    // Seed a prior successful result so we can prove the failure clears it.
    vm.handleCourtSelect(court("old"))

    await vm.handleSearch(query: "Ballard")

    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertFalse(vm.loading)
    XCTAssertEqual(vm.error, "Geocoding REQUEST_DENIED")
  }

  func testGeolocateSuccessSearchesAroundTheDeviceLocation() async {
    let places = FakePlacesProvider(searchResult: .success([court("1")]))
    let vm = makeViewModel(places: places, location: CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3))

    await vm.handleGeolocate()

    XCTAssertEqual(vm.courts.map(\.id), ["1"])
    XCTAssertEqual(vm.center, LatLng(lat: 47.6, lng: -122.3))
    XCTAssertEqual(vm.zoom, 12)
    XCTAssertEqual(places.searchLocations, [LatLng(lat: 47.6, lng: -122.3)])
  }

  func testGeolocateDeniedSurfacesErrorWithoutSearching() async {
    let places = FakePlacesProvider(searchResult: .success([court("1")]))
    let vm = makeViewModel(places: places, location: nil)

    await vm.handleGeolocate()

    XCTAssertEqual(vm.error, AppCopy.Errors.geolocationDenied)
    XCTAssertTrue(vm.courts.isEmpty)
    XCTAssertFalse(vm.loading)
    XCTAssertTrue(places.searchLocations.isEmpty)
  }

  func testSelectingACourtCentersOnItAndDerivesSelection() async {
    let target = court("2", lat: 40, lng: -75)
    let places = FakePlacesProvider(searchResult: .success([court("1"), target]))
    let vm = makeViewModel(places: places)
    await vm.handleSearch(query: "Ballard")

    vm.handleCourtSelect(target)

    XCTAssertEqual(vm.selectedId, "2")
    XCTAssertEqual(vm.selectedCourt, target)
    XCTAssertEqual(vm.center, target.location)
  }

  func testEachSuccessfulSearchBumpsTheSequence() async {
    let places = FakePlacesProvider(searchResult: .success([court("1")]))
    let vm = makeViewModel(places: places)

    await vm.handleSearch(query: "Ballard")
    await vm.handleSearch(query: "Fremont")

    XCTAssertEqual(vm.searchSeq, 2)
  }
}
