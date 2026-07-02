import MapKit
import SwiftUI

/// Google-style integer zoom -> a latitude/longitude span. Rough but matches
/// the original app's map framing closely enough (zoom 4 ~= whole US, 12 ~= a
/// metro area). Ported verbatim from `CourtMap.native.tsx`'s `deltaForZoom`.
private func deltaForZoom(_ zoom: Int) -> Double {
  360 / pow(2, Double(zoom))
}

private func region(center: LatLng, zoom: Int) -> MKCoordinateRegion {
  let delta = deltaForZoom(zoom)
  return MKCoordinateRegion(
    center: center.coordinate,
    span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta),
  )
}

/// Apple MapKit map with numbered pin annotations -- the original app used
/// Google Maps (web) / react-native-maps (native); this app renders with
/// MapKit instead (no map API key needed) while still sourcing court data
/// from Google Places (see GooglePlacesClient).
struct CourtMapView: View {
  let courts: [Court]
  let selectedId: String?
  let center: LatLng
  let zoom: Int
  let onSelectCourt: (Court) -> Void

  @State private var cameraPosition: MapCameraPosition
  @State private var mapSelection: String?

  init(
    courts: [Court],
    selectedId: String?,
    center: LatLng,
    zoom: Int,
    onSelectCourt: @escaping (Court) -> Void,
  ) {
    self.courts = courts
    self.selectedId = selectedId
    self.center = center
    self.zoom = zoom
    self.onSelectCourt = onSelectCourt
    _cameraPosition = State(initialValue: .region(region(center: center, zoom: zoom)))
    _mapSelection = State(initialValue: selectedId)
  }

  var body: some View {
    Map(position: $cameraPosition, selection: $mapSelection) {
      ForEach(Array(courts.enumerated()), id: \.element.id) { index, court in
        Annotation(court.name, coordinate: court.location.coordinate) {
          CourtPinView(number: index + 1, selected: court.id == selectedId)
        }
        .tag(court.id)
      }
    }
    .mapControls {
      MapCompass()
    }
    // Camera movement on search animates, mirroring the original app's
    // `animateToRegion(_, 500)`. Selecting a court recenters but does not
    // change zoom -- only `center` drives this, `zoom` stays whatever it was.
    .onChange(of: center) { _, newCenter in
      withAnimation(.easeInOut(duration: 0.5)) {
        cameraPosition = .region(region(center: newCenter, zoom: zoom))
      }
    }
    .onChange(of: mapSelection) { _, newSelection in
      guard let newSelection, let court = courts.first(where: { $0.id == newSelection }) else { return }
      onSelectCourt(court)
    }
    .onChange(of: selectedId) { _, newValue in
      mapSelection = newValue
    }
  }
}
