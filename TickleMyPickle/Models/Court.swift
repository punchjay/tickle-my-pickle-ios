import CoreLocation

/// A view-model for a pickleball court, decoded from the Places API (New)
/// `searchText` response. Platform-agnostic lat/lng type (rather than storing
/// `CLLocationCoordinate2D` directly) so `Court` stays `Codable`/`Hashable`
/// for free -- `CLLocationCoordinate2D` conforms to neither on its own.
struct LatLng: Codable, Hashable, Sendable {
  var lat: Double
  var lng: Double

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lng)
  }
}

struct Court: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let name: String
  let address: String
  var rating: Double?
  var userRatingCount: Int?
  var isOpen: Bool?
  /// Coarse Google Place `types` (e.g. "park", "gym"). Kept only as input to
  /// the amenity heuristic (`inferAmenities`); never displayed directly.
  var types: [String]?
  var location: LatLng
}
