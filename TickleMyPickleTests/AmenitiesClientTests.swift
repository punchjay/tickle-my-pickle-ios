import XCTest
@testable import TickleMyPickle

final class AmenitiesClientTests: XCTestCase {
  private var session: URLSession!
  private let endpoint = URL(string: "https://amenities.example.com/amenities")!

  override func setUp() {
    super.setUp()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    session = URLSession(configuration: config)
  }

  func testDecodesAnswersKeyedByPlaceId() async throws {
    URLProtocolStub.statusCode = 200
    URLProtocolStub.responseData = Data("""
    {"amenities":{"abc":{"indoor":true,"outdoor":null,"lighted":false,"free":null,
      "courtCount":6,"dedicatedCourts":true,"netsProvided":null,"evidence":["6 indoor courts"]}}}
    """.utf8)

    let service = ReviewAmenitiesService(endpoint: endpoint, session: session)
    let result = try await service.amenities(for: ["abc", "def"])

    XCTAssertEqual(result.keys.sorted(), ["abc"])
    XCTAssertEqual(result["abc"]?.indoor, true)
    XCTAssertEqual(result["abc"]?.lighted, false)
    XCTAssertNil(result["abc"]?.outdoor)
    XCTAssertEqual(result["abc"]?.courtCount, 6)
    XCTAssertEqual(result["abc"]?.evidence, ["6 indoor courts"])
  }

  func testThrowsOnServerError() async {
    URLProtocolStub.statusCode = 500
    URLProtocolStub.responseData = Data()

    let service = ReviewAmenitiesService(endpoint: endpoint, session: session)
    do {
      _ = try await service.amenities(for: ["abc"])
      XCTFail("expected a server error to throw")
    } catch {}
  }

  func testWithNoBackendConfiguredReturnsNothing() async throws {
    let service = ReviewAmenitiesService(endpoint: nil, session: session)
    let result = try await service.amenities(for: ["abc"])
    XCTAssertTrue(result.isEmpty)
  }
}
