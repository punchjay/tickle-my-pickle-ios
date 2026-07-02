import Foundation

/// The data + selection state machine behind the finder, ported from the
/// original app's `usePickleballMap.ts`. Google REST calls are plain
/// URLSession async/await (GooglePlacesClient), so there's no JS-SDK-style
/// lazy-load to gate on -- state stays a simple loading/error pair.
@Observable
@MainActor
final class PickleballMapViewModel {
  /// Center of the contiguous US -- the map's initial framing before any search.
  static let usCenter = LatLng(lat: 39.8283, lng: -98.5795)

  private(set) var courts: [Court] = []
  /// Selection is stored as the court's id; `selectedCourt` is derived from
  /// the current list, so a rebuilt list can't disagree with it.
  private(set) var selectedId: String?
  var selectedCourt: Court? {
    courts.first { $0.id == selectedId }
  }

  /// Map framing. `center` recenters on each search; the view turns this into
  /// a MapKit camera. Starts zoomed out on the US, tightens after a search.
  private(set) var center: LatLng = usCenter
  private(set) var zoom: Int = 4
  /// Bumped on each fresh result set; used as a SwiftUI `.id()` to replay the
  /// list's entrance transition on every search.
  private(set) var searchSeq = 0
  private(set) var loading = false
  var error: String? = Config.hasApiKey ? nil : AppCopy.Errors.missingApiKey

  let hasApiKey = Config.hasApiKey

  private let locationService = LocationService()

  /// Shared tail of search + geolocate: run the Places text search around a
  /// resolved location, map results, recenter, and surface errors.
  private func searchNearby(_ location: LatLng) async {
    defer { loading = false }
    do {
      let results = try await GooglePlacesClient.searchCourts(near: location)
      if results.isEmpty {
        courts = []
        error = AppCopy.Errors.noCourtsFound
        return
      }
      selectedId = nil
      center = location
      zoom = 12
      courts = results
      searchSeq += 1
    } catch {
      print("Places searchText failed: \(error)")
      courts = []
      // In debug builds, surface Google's actual reason (e.g. REQUEST_DENIED
      // from a key restriction) on-screen; ship the friendly message in release.
      #if DEBUG
        self.error = error.localizedDescription
      #else
        self.error = AppCopy.Errors.searchFailed
      #endif
    }
  }

  func handleSearch(query: String) async {
    guard hasApiKey else { return }
    loading = true
    error = nil
    do {
      guard let location = try await GooglePlacesClient.geocode(query: query) else {
        loading = false
        error = AppCopy.Errors.locationNotFound
        return
      }
      await searchNearby(location)
    } catch {
      print("Geocoding failed: \(error)")
      loading = false
      #if DEBUG
        self.error = error.localizedDescription
      #else
        self.error = AppCopy.Errors.locationNotFound
      #endif
    }
  }

  func handleGeolocate() async {
    guard hasApiKey else { return }
    loading = true
    error = nil
    guard let coordinate = await locationService.requestOneShotLocation() else {
      loading = false
      error = AppCopy.Errors.geolocationDenied
      return
    }
    await searchNearby(LatLng(lat: coordinate.latitude, lng: coordinate.longitude))
  }

  func handleCourtSelect(_ court: Court) {
    selectedId = court.id
    center = court.location
  }
}
