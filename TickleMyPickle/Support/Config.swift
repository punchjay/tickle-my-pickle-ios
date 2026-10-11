import Foundation

/// Google Maps REST key, read from Info.plist (populated at build time from
/// `Secrets.xcconfig` via `$(GOOGLE_MAPS_REST_API_KEY)` substitution -- see
/// project.yml). Unlike the old Expo app, one key covers all REST calls: it's
/// restricted to this app's bundle id in Google Cloud Console rather than by
/// HTTP referrer, and GooglePlacesClient sends the matching
/// X-Ios-Bundle-Identifier header on every request.
enum Config {
  static let googleMapsRestAPIKey: String =
    (Bundle.main.object(forInfoDictionaryKey: "GoogleMapsRestAPIKey") as? String) ?? ""

  /// Treat the Secrets.xcconfig.example placeholder as "no key", same as the
  /// original app's `.env.example` convention, so dev without a real key shows
  /// the friendly missing-key error instead of failing every Places call.
  static let hasApiKey: Bool =
    !googleMapsRestAPIKey.isEmpty && googleMapsRestAPIKey != "YOUR_KEY_HERE"

  /// Amenities backend (the Worker in `backend/`), read from Info.plist via
  /// `$(AMENITIES_API_HOST)`. A bare host rather than a URL because
  /// xcconfig treats `//` as a comment, which would cut `https://` short.
  /// Unset means the review-amenities feature is off.
  static let amenitiesAPIURL: URL? = {
    guard
      let host = Bundle.main.object(forInfoDictionaryKey: "AmenitiesAPIHost") as? String,
      !host.isEmpty
    else { return nil }
    return URL(string: "https://\(host)/amenities")
  }()
}
