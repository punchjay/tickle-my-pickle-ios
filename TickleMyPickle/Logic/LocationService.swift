import CoreLocation

/// Outcome of a one-shot location request, kept distinct so callers can tell
/// "permission denied" apart from "permission granted but no fix was
/// obtained" (GPS timeout, airplane mode, no simulated location set, etc.) --
/// collapsing both to `nil` produced a misleading "access denied" message for
/// failures that had nothing to do with permissions.
enum LocationResult {
  case success(CLLocationCoordinate2D)
  case denied
  case unavailable
}

/// Seam over the location source so `PickleballMapViewModel`'s geolocate flow
/// can be tested with a stub. `LocationService` is the live implementation.
@MainActor
protocol LocationProviding {
  func requestOneShotLocation() async -> LocationResult
}

/// Seam over `CLLocationManager` itself (as opposed to `LocationProviding`,
/// which seams over the whole one-shot flow) so `LocationService`'s
/// authorization/delegate bookkeeping can be tested with a fake manager
/// instead of the real, permission-prompting, simulator-dependent one.
@MainActor
protocol CLLocationManagerProtocol: AnyObject {
  var delegate: CLLocationManagerDelegate? { get set }
  var authorizationStatus: CLAuthorizationStatus { get }
  func requestWhenInUseAuthorization()
  func requestLocation()
}

extension CLLocationManager: CLLocationManagerProtocol {}

/// One-shot "get current location" wrapper around the classic
/// CLLocationManagerDelegate API. Deliberately not CLLocationUpdate
/// .liveUpdates() (iOS 17's AsyncSequence-based API): that one has a known
/// history of unreliable delivery specifically in the iOS Simulator, and this
/// whole project's iteration loop is Simulator-only. manager.requestLocation()
/// is itself already a one-shot primitive and is what `xcrun simctl location
/// <device> set <lat>,<lon>` is built to drive for scripted verification.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
  private let manager: any CLLocationManagerProtocol
  private var authorizationContinuation: CheckedContinuation<Void, Never>?
  private var locationContinuation: CheckedContinuation<LocationResult, Never>?

  init(manager: any CLLocationManagerProtocol = CLLocationManager()) {
    self.manager = manager
    super.init()
    self.manager.delegate = self
  }

  func requestOneShotLocation() async -> LocationResult {
    if manager.authorizationStatus == .notDetermined {
      await withCheckedContinuation { continuation in
        self.authorizationContinuation = continuation
        manager.requestWhenInUseAuthorization()
      }
    }

    guard manager.authorizationStatus == .authorizedWhenInUse
      || manager.authorizationStatus == .authorizedAlways
    else {
      return .denied
    }

    return await withCheckedContinuation { continuation in
      self.locationContinuation = continuation
      manager.requestLocation()
    }
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      self.authorizationContinuation?.resume()
      self.authorizationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    Task { @MainActor in
      if let coordinate = locations.first?.coordinate {
        self.locationContinuation?.resume(returning: .success(coordinate))
      } else {
        self.locationContinuation?.resume(returning: .unavailable)
      }
      self.locationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      self.locationContinuation?.resume(returning: .unavailable)
      self.locationContinuation = nil
    }
  }
}
