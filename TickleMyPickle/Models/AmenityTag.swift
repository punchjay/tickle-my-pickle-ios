/// Amenity tagging types. Every tag is an *inference* from the listing name
/// and coarse Place `types` -- the Places API (New) fields requested carry no
/// structured indoor/outdoor/amenity signal. See `Amenities.swift`.
enum AmenityKind: String, Sendable, Hashable {
  case indoor
  case outdoor
  case lighted
  case free
}

enum Confidence: Int, Sendable {
  case low = 1
  case high = 2
}

struct Tag: Sendable {
  let kind: AmenityKind
  let confidence: Confidence
}
