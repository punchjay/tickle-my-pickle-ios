import CoreLocation
import XCTest

@testable import TickleMyPickle

/// Fake `CLLocationManagerProtocol` so `LocationService`'s authorization and
/// delegate-callback bookkeeping can be driven deterministically, without a
/// real (permission-prompting, simulator-dependent) `CLLocationManager`.
@MainActor
final class FakeCLLocationManager: CLLocationManagerProtocol {
  weak var delegate: CLLocationManagerDelegate?
  var authorizationStatus: CLAuthorizationStatus
  private(set) var requestedAuthorization = false
  private(set) var requestedLocation = false

  init(authorizationStatus: CLAuthorizationStatus) {
    self.authorizationStatus = authorizationStatus
  }

  func requestWhenInUseAuthorization() { requestedAuthorization = true }
  func requestLocation() { requestedLocation = true }
}

private struct StubLocationError: Error {}

@MainActor
final class LocationServiceTests: XCTestCase {
  /// `LocationService`'s delegate methods resume their continuations from a
  /// separately-scheduled `Task { @MainActor in ... }` rather than
  /// synchronously, so a plain assertion right after spawning/signalling
  /// wouldn't reliably observe the effect yet. Poll with cooperative yields
  /// instead of guessing how many hops the scheduler needs.
  private func waitUntil(
    _ condition: @autoclosure () -> Bool,
    tries: Int = 50,
  ) async {
    for _ in 0..<tries {
      if condition() { return }
      await Task.yield()
    }
    XCTFail("condition never became true")
  }

  func testDeniedPermissionReturnsDeniedWithoutRequestingLocation() async {
    let manager = FakeCLLocationManager(authorizationStatus: .denied)
    let service = LocationService(manager: manager)

    let result = await service.requestOneShotLocation()

    guard case .denied = result else { return XCTFail("expected .denied, got \(result)") }
    XCTAssertFalse(manager.requestedLocation)
  }

  func testAuthorizedManagerRequestsLocationAndReturnsCoordinateOnSuccess() async {
    let manager = FakeCLLocationManager(authorizationStatus: .authorizedWhenInUse)
    let service = LocationService(manager: manager)

    let task = Task { await service.requestOneShotLocation() }
    await waitUntil(manager.requestedLocation)

    service.locationManager(
      CLLocationManager(),
      didUpdateLocations: [CLLocation(latitude: 47.6, longitude: -122.3)],
    )

    guard case .success(let coordinate) = await task.value else {
      return XCTFail("expected .success")
    }
    XCTAssertEqual(coordinate.latitude, 47.6)
    XCTAssertEqual(coordinate.longitude, -122.3)
  }

  func testAuthorizedManagerReturnsUnavailableOnDelegateError() async {
    // Permission granted but the fix itself failed (GPS timeout, airplane
    // mode, etc.) -- must not be reported the same as a denied permission.
    let manager = FakeCLLocationManager(authorizationStatus: .authorizedWhenInUse)
    let service = LocationService(manager: manager)

    let task = Task { await service.requestOneShotLocation() }
    await waitUntil(manager.requestedLocation)

    service.locationManager(CLLocationManager(), didFailWithError: StubLocationError())

    guard case .unavailable = await task.value else { return XCTFail("expected .unavailable") }
  }

  func testAuthorizedManagerReturnsUnavailableWhenNoLocationsAreDelivered() async {
    // CLLocationManager can call didUpdateLocations with an empty array;
    // that's a fix failure too, not a permissions problem.
    let manager = FakeCLLocationManager(authorizationStatus: .authorizedWhenInUse)
    let service = LocationService(manager: manager)

    let task = Task { await service.requestOneShotLocation() }
    await waitUntil(manager.requestedLocation)

    service.locationManager(CLLocationManager(), didUpdateLocations: [])

    guard case .unavailable = await task.value else { return XCTFail("expected .unavailable") }
  }

  func testNotDeterminedThenGrantedRequestsAuthorizationThenLocation() async {
    let manager = FakeCLLocationManager(authorizationStatus: .notDetermined)
    let service = LocationService(manager: manager)

    let task = Task { await service.requestOneShotLocation() }
    await waitUntil(manager.requestedAuthorization)
    XCTAssertFalse(manager.requestedLocation, "must not request a fix before authorization resolves")

    manager.authorizationStatus = .authorizedWhenInUse
    service.locationManagerDidChangeAuthorization(CLLocationManager())
    await waitUntil(manager.requestedLocation)

    service.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 10, longitude: 20)])

    guard case .success(let coordinate) = await task.value else {
      return XCTFail("expected .success")
    }
    XCTAssertEqual(coordinate.latitude, 10)
    XCTAssertEqual(coordinate.longitude, 20)
  }

  func testNotDeterminedThenDeniedReturnsDeniedWithoutRequestingLocation() async {
    let manager = FakeCLLocationManager(authorizationStatus: .notDetermined)
    let service = LocationService(manager: manager)

    let task = Task { await service.requestOneShotLocation() }
    await waitUntil(manager.requestedAuthorization)

    manager.authorizationStatus = .denied
    service.locationManagerDidChangeAuthorization(CLLocationManager())

    guard case .denied = await task.value else { return XCTFail("expected .denied") }
    XCTAssertFalse(manager.requestedLocation)
  }
}
