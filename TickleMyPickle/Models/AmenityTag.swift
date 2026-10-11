/// Amenity tagging types. A tag comes either from the court's reviews (read
/// by Claude in the amenities backend) or, failing that, is an *inference*
/// from the listing name and coarse Place `types`. See `Amenities.swift`.
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
