import Foundation

/// Google Maps data layer -- REST, not a Google SDK, mirroring the original
/// app's `lib/places.ts`:
///   - Geocoding API   (free-text location -> lat/lng)
///   - Places API (New) Text Search ("pickleball court" near a location)
enum GooglePlacesError: Error, LocalizedError {
  case geocoding(status: String, message: String?)
  case places(message: String)

  var errorDescription: String? {
    switch self {
    case .geocoding(let status, let message):
      return "Geocoding \(status)" + (message.map { ": \($0)" } ?? "")
    case .places(let message):
      return "Places \(message)"
    }
  }
}

enum GooglePlacesClient {
  /// ~10 miles.
  static let searchRadiusMeters: Double = 16093

  /// Every Google REST request needs both the API key and, since the key is
  /// restricted to this app's bundle id (not by referrer), the matching
  /// X-Ios-Bundle-Identifier header -- centralized here so a future call site
  /// can't forget it and get a silent REQUEST_DENIED.
  private static func makeRequest(url: URL, method: String = "GET") -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    return request
  }

  private struct GeocodeResponse: Decodable {
    struct Result: Decodable {
      struct Geometry: Decodable {
        let location: LatLng
      }
      let geometry: Geometry
    }
    let status: String
    let error_message: String?
    let results: [Result]?
  }

  /// Geocode a free-text query (city, ZIP, neighborhood), restricted to the US
  /// to match the original app. Returns nil when nothing usable comes back.
  /// `session` defaults to `.shared`; tests inject a stubbed session.
  static func geocode(query: String, session: URLSession = .shared) async throws -> LatLng? {
    var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
    components.queryItems = [
      URLQueryItem(name: "address", value: query),
      URLQueryItem(name: "components", value: "country:US"),
      URLQueryItem(name: "key", value: Config.googleMapsRestAPIKey),
    ]
    let request = makeRequest(url: components.url!)
    let (data, _) = try await session.data(for: request)
    let decoded = try JSONDecoder().decode(GeocodeResponse.self, from: data)

    // ZERO_RESULTS is a normal "not found"; surface real failures
    // (REQUEST_DENIED from a key restriction, OVER_QUERY_LIMIT, etc.) with
    // Google's own reason so a misrestricted key doesn't masquerade as
    // "location not found".
    guard decoded.status == "OK" else {
      if decoded.status == "ZERO_RESULTS" { return nil }
      throw GooglePlacesError.geocoding(status: decoded.status, message: decoded.error_message)
    }
    return decoded.results?.first?.geometry.location
  }

  private struct SearchTextRequestBody: Encodable {
    struct LocationBias: Encodable {
      struct Circle: Encodable {
        struct Center: Encodable {
          let latitude: Double
          let longitude: Double
        }
        let center: Center
        let radius: Double
      }
      let circle: Circle
    }
    let textQuery: String
    let locationBias: LocationBias
    let maxResultCount: Int
  }

  /// Shape of a Place in the Places API (New) searchText response (only the
  /// fields our field mask requests).
  private struct PlaceResult: Decodable {
    struct DisplayName: Decodable { let text: String? }
    struct OpeningHours: Decodable { let openNow: Bool?
      enum CodingKeys: String, CodingKey { case openNow }
    }
    /// Places API (New) uses `{latitude, longitude}` -- different key names
    /// than Geocoding's `{lat, lng}` (which matches `LatLng` directly). Do not
    /// reuse `LatLng` here; convert via `.latLng` instead.
    struct PlaceLocation: Decodable {
      let latitude: Double
      let longitude: Double
      var latLng: LatLng { LatLng(lat: latitude, lng: longitude) }
    }
    let id: String
    let displayName: DisplayName?
    let formattedAddress: String?
    let location: PlaceLocation?
    let rating: Double?
    let userRatingCount: Int?
    let types: [String]?
    let currentOpeningHours: OpeningHours?
  }

  private struct SearchTextResponse: Decodable {
    let places: [PlaceResult]?
  }

  /// Text search for pickleball courts biased to a location. The New API
  /// returns `currentOpeningHours.openNow` directly, so there's no per-place
  /// isOpen() round trip. Maps the response into the local `Court` view-model
  /// so the rest of the app never sees the wire shape.
  static func searchCourts(near location: LatLng, session: URLSession = .shared) async throws -> [Court] {
    var request = makeRequest(
      url: URL(string: "https://places.googleapis.com/v1/places:searchText")!,
      method: "POST",
    )
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(Config.googleMapsRestAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
    request.setValue(
      [
        "places.id",
        "places.displayName",
        "places.formattedAddress",
        "places.location",
        "places.rating",
        "places.userRatingCount",
        "places.types",
        "places.currentOpeningHours.openNow",
      ].joined(separator: ","),
      forHTTPHeaderField: "X-Goog-FieldMask",
    )

    let body = SearchTextRequestBody(
      textQuery: AppCopy.searchQuery,
      locationBias: .init(
        circle: .init(
          center: .init(latitude: location.lat, longitude: location.lng),
          radius: searchRadiusMeters,
        ),
      ),
      maxResultCount: 20,
    )
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await session.data(for: request)

    // Places (New) returns errors as JSON { error: { status, message } } (e.g.
    // 403 PERMISSION_DENIED from a key restriction). Surface Google's message
    // so the failure is diagnosable rather than a bare HTTP status.
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { let status: String?; let message: String? }
        let error: Detail?
      }
      let detail = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
      let reason = detail?.error?.message ?? "HTTP \(http.statusCode)"
      throw GooglePlacesError.places(message: reason)
    }

    let decoded = try JSONDecoder().decode(SearchTextResponse.self, from: data)
    return (decoded.places ?? []).map { place in
      Court(
        id: place.id,
        name: place.displayName?.text ?? AppCopy.unknownCourt,
        address: place.formattedAddress ?? "",
        rating: place.rating,
        userRatingCount: place.userRatingCount,
        isOpen: place.currentOpeningHours?.openNow,
        types: place.types,
        location: place.location?.latLng ?? location,
      )
    }
  }
}
