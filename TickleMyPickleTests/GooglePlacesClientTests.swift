import XCTest
@testable import TickleMyPickle

/// Intercepts every request on a session it's registered with and returns a
/// canned response, so GooglePlacesClient's status/error mapping can be
/// tested without a network call.
final class URLProtocolStub: URLProtocol {
  nonisolated(unsafe) static var responseData: Data = Data()
  nonisolated(unsafe) static var statusCode: Int = 200

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: Self.statusCode,
      httpVersion: nil,
      headerFields: nil,
    )!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Self.responseData)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

final class GooglePlacesClientTests: XCTestCase {
  private var session: URLSession!

  override func setUp() {
    super.setUp()
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    session = URLSession(configuration: config)
  }

  func testGeocodeReturnsCoordinateOnOK() async throws {
    URLProtocolStub.statusCode = 200
    URLProtocolStub.responseData = Data("""
    {"status":"OK","results":[{"geometry":{"location":{"lat":47.6,"lng":-122.3}}}]}
    """.utf8)

    let result = try await GooglePlacesClient.geocode(query: "Seattle", session: session)
    XCTAssertEqual(result?.lat, 47.6)
    XCTAssertEqual(result?.lng, -122.3)
  }

  func testGeocodeReturnsNilOnZeroResults() async throws {
    URLProtocolStub.statusCode = 200
    URLProtocolStub.responseData = Data(#"{"status":"ZERO_RESULTS"}"#.utf8)

    let result = try await GooglePlacesClient.geocode(query: "nowhere", session: session)
    XCTAssertNil(result)
  }

  func testGeocodeThrowsWithGoogleReasonOnRequestDenied() async {
    URLProtocolStub.statusCode = 200
    URLProtocolStub.responseData = Data("""
    {"status":"REQUEST_DENIED","error_message":"API keys with referer restrictions cannot be used with this API."}
    """.utf8)

    do {
      _ = try await GooglePlacesClient.geocode(query: "Seattle", session: session)
      XCTFail("expected geocode to throw")
    } catch let error as GooglePlacesError {
      guard case .geocoding(let status, let message) = error else {
        return XCTFail("wrong error case: \(error)")
      }
      XCTAssertEqual(status, "REQUEST_DENIED")
      XCTAssertEqual(message, "API keys with referer restrictions cannot be used with this API.")
    } catch {
      XCTFail("wrong error type: \(error)")
    }
  }

  func testSearchCourtsMapsPlacesResponse() async throws {
    URLProtocolStub.statusCode = 200
    URLProtocolStub.responseData = Data("""
    {"places":[{"id":"abc123","displayName":{"text":"Riverside Courts"},
    "formattedAddress":"1 Main St","location":{"latitude":1,"longitude":2},
    "rating":4.5,"userRatingCount":10,"types":["park"],
    "currentOpeningHours":{"openNow":true}}]}
    """.utf8)

    let courts = try await GooglePlacesClient.searchCourts(
      near: LatLng(lat: 0, lng: 0),
      session: session,
    )
    XCTAssertEqual(courts.count, 1)
    XCTAssertEqual(courts[0].id, "abc123")
    XCTAssertEqual(courts[0].name, "Riverside Courts")
    XCTAssertEqual(courts[0].isOpen, true)
  }

  func testSearchCourtsThrowsWithGoogleMessageOnNonSuccess() async {
    URLProtocolStub.statusCode = 403
    URLProtocolStub.responseData = Data("""
    {"error":{"status":"PERMISSION_DENIED","message":"This API key is not authorized."}}
    """.utf8)

    do {
      _ = try await GooglePlacesClient.searchCourts(near: LatLng(lat: 0, lng: 0), session: session)
      XCTFail("expected searchCourts to throw")
    } catch let error as GooglePlacesError {
      guard case .places(let message) = error else {
        return XCTFail("wrong error case: \(error)")
      }
      XCTAssertEqual(message, "This API key is not authorized.")
    } catch {
      XCTFail("wrong error type: \(error)")
    }
  }
}
