import CoreLocation
import XCTest

@testable import TickleMyPickle

final class CourtModelTests: XCTestCase {
  func testLatLngCoordinateConvertsLatAndLng() {
    let coordinate = LatLng(lat: 47.6, lng: -122.3).coordinate

    XCTAssertEqual(coordinate.latitude, 47.6)
    XCTAssertEqual(coordinate.longitude, -122.3)
  }

  func testCourtDecodesWithOptionalFieldsMissing() throws {
    // FavoritesStore and GooglePlacesClient both rely on Court's synthesized
    // Codable filling in nil for absent optional keys, not failing to decode.
    let json = Data("""
    {"id":"1","name":"Test Court","address":"123 Main St","location":{"lat":1,"lng":2}}
    """.utf8)

    let court = try JSONDecoder().decode(Court.self, from: json)

    XCTAssertEqual(court.id, "1")
    XCTAssertNil(court.rating)
    XCTAssertNil(court.userRatingCount)
    XCTAssertNil(court.isOpen)
    XCTAssertNil(court.types)
    XCTAssertEqual(court.location, LatLng(lat: 1, lng: 2))
  }

  func testCourtRoundTripsThroughJSONEncodingAndDecoding() throws {
    let original = Court(
      id: "abc", name: "Round Trip Court", address: "1 Loop Rd",
      rating: 4.5, userRatingCount: 12, isOpen: true, types: ["park"],
      location: LatLng(lat: 3, lng: 4),
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Court.self, from: data)

    XCTAssertEqual(decoded, original)
  }
}
