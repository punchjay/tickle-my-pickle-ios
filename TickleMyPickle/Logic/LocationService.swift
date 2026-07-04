import CoreLocation

/// Seam over the location source so `PickleballMapViewModel`'s geolocate flow
/// can be tested with a stub. `LocationService` is the live implementation.
@MainActor
protocol LocationProviding {
  func requestOneShotLocation() async -> CLLocationCoordinate2D?
}

/// One-shot "get current location" wrapper around the classic
/// CLLocationManagerDelegate API. Deliberately not CLLocationUpdate
/// .liveUpdates() (iOS 17's AsyncSequence-based API): that one has a known
/// history of unreliable delivery specifically in the iOS Simulator, and this
/// whole project's iteration loop is Simulator-only. manager.requestLocation()
/// is itself already a one-shot primitive and is what `xcrun simctl location
/// <device> set <lat>,<lon>` is built to drive for scripted verification.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
  private let manager = CLLocationManager()
  private var authorizationContinuation: CheckedContinuation<Void, Never>?
  private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

  override init() {
    super.init()
    manager.delegate = self
  }

  /// Resolves to nil if permission is denied/restricted or the location fetch
  /// fails; otherwise the device's current coordinate.
  func requestOneShotLocation() async -> CLLocationCoordinate2D? {
    if manager.authorizationStatus == .notDetermined {
      await withCheckedContinuation { continuation in
        self.authorizationContinuation = continuation
        manager.requestWhenInUseAuthorization()
      }
    }

    guard manager.authorizationStatus == .authorizedWhenInUse
      || manager.authorizationStatus == .authorizedAlways
    else {
      return nil
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
      self.locationContinuation?.resume(returning: locations.first?.coordinate)
      self.locationContinuation = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      self.locationContinuation?.resume(returning: nil)
      self.locationContinuation = nil
    }
  }
}
