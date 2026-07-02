import XCTest
@testable import TickleMyPickle

final class AmenitiesTests: XCTestCase {
  private func court(_ name: String, types: [String] = []) -> Court {
    Court(id: "x", name: name, address: "", types: types, location: LatLng(lat: 0, lng: 0))
  }

  private func kinds(_ court: Court) -> [AmenityKind] {
    Amenities.inferAmenities(for: court).map(\.kind)
  }

  func testTagsARecCenterAsHighConfidenceIndoor() {
    let tags = Amenities.inferAmenities(for: court("Eastside Recreation Center"))
    XCTAssertTrue(tags.contains { $0.kind == .indoor && $0.confidence == .high })
  }

  func testTagsAParkAsOutdoorAndFreeHighConfidence() {
    let tags = Amenities.inferAmenities(for: court("Riverside Park", types: ["park"]))
    XCTAssertTrue(tags.contains { $0.kind == .outdoor && $0.confidence == .high })
    XCTAssertTrue(tags.contains { $0.kind == .free && $0.confidence == .high })
  }

  func testSuppressesFreeForAPrivateClubEvenWithParkType() {
    XCTAssertFalse(kinds(court("Pickle Club", types: ["park"])).contains(.free))
  }

  func testTagsLightedFromTheName() {
    XCTAssertTrue(kinds(court("Lighted Courts at 5th")).contains(.lighted))
  }

  func testDropsBothIndoorAndOutdoorOnAnEqualConfidenceTie() {
    // "club" -> indoor low, "tennis center" -> outdoor low: tie, so neither.
    let k = kinds(court("Tennis Center Club"))
    XCTAssertFalse(k.contains(.indoor))
    XCTAssertFalse(k.contains(.outdoor))
  }
}
