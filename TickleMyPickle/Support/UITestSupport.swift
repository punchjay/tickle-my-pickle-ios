import CoreLocation
import Foundation

extension PickleballMapViewModel {
  /// The view model `RootView` launches with. Production builds always get the
  /// live implementation; under UI tests (Debug only) a launch argument swaps in
  /// deterministic stub data so the landing → results flow can be driven with no
  /// network, no API key, and no location-permission prompt.
  static func forLaunch() -> PickleballMapViewModel {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains(uiTestStubArgument) {
        return PickleballMapViewModel(
          places: UITestPlacesStub(),
          locationProvider: UITestLocationStub(),
          hasApiKey: true,
        )
      }
    #endif
    return PickleballMapViewModel()
  }
}

#if DEBUG
  /// Launch argument that activates the stub data path. A plain string literal
  /// so the app and the UI-test bundle (separate processes) can agree on it
  /// without sharing a module. Keep in sync with `LandingFlowUITests`.
  let uiTestStubArgument = "-uiTestStubData"

  /// Canned courts returned for any query/location, so the results UI is fully
  /// deterministic under test. Stateless, so `Sendable` is automatic.
  struct UITestPlacesStub: PlacesProviding {
    func geocode(query: String) async throws -> LatLng? {
      LatLng(lat: 47.6685, lng: -122.3860) // Ballard, Seattle
    }

    func searchCourts(near location: LatLng) async throws -> [Court] {
      [
        Court(
          id: "stub-1", name: "Ballard Community Court", address: "1471 NW 67th St",
          rating: 4.7, userRatingCount: 128, isOpen: true, types: ["park"],
          location: LatLng(lat: 47.6762, lng: -122.3822),
        ),
        Court(
          id: "stub-2", name: "Green Lake Pickleball", address: "7201 E Green Lake Dr N",
          rating: 4.5, userRatingCount: 96, isOpen: false, types: ["gym"],
          location: LatLng(lat: 47.6806, lng: -122.3270),
        ),
      ]
    }
  }

  /// Fixed coordinate for the "Near me" path, so geolocate never prompts.
  @MainActor
  struct UITestLocationStub: LocationProviding {
    func requestOneShotLocation() async -> CLLocationCoordinate2D? {
      CLLocationCoordinate2D(latitude: 47.6685, longitude: -122.3860)
    }
  }
#endif
