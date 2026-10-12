import Foundation

/// Seam over the review-amenities backend so `PickleballMapViewModel` can be
/// driven by a stub in tests. Returns answers keyed by place id; a place the
/// backend has nothing for is simply absent.
protocol AmenitiesProviding: Sendable {
  func amenities(for placeIds: [String]) async throws -> [String: ReviewAmenities]
}

/// Live `AmenitiesProviding`, backed by the Cloudflare Worker in `backend/`.
/// The app sends place ids only; the Worker fetches the reviews and asks
/// Claude, so no Anthropic key ever ships in the app. With no backend
/// configured (`Config.amenitiesAPIURL` nil) it returns nothing, and every
/// court keeps its name-based tags.
struct ReviewAmenitiesService: AmenitiesProviding {
  var endpoint: URL? = Config.amenitiesAPIURL
  var session: URLSession = .shared

  private struct RequestBody: Encodable { let placeIds: [String] }
  private struct ResponseBody: Decodable { let amenities: [String: ReviewAmenities] }

  func amenities(for placeIds: [String]) async throws -> [String: ReviewAmenities] {
    guard let endpoint, !placeIds.isEmpty else { return [:] }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(RequestBody(placeIds: placeIds))

    let (data, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(ResponseBody.self, from: data).amenities
  }
}
