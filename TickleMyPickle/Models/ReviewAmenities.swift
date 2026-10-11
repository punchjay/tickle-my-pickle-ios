/// What a court's Google reviews say about it, as read by Claude in the
/// amenities backend (`backend/`). Every field is optional: nil means "the
/// reviews don't say", and `Amenities` then falls back to its name-based
/// guess. Wire shape matches the Worker's `ReviewAmenities` zod schema.
struct ReviewAmenities: Codable, Hashable, Sendable {
  var indoor: Bool?
  var outdoor: Bool?
  var lighted: Bool?
  var free: Bool?
  var courtCount: Int?
  var dedicatedCourts: Bool?
  var netsProvided: Bool?
  /// Short review quotes backing the fields above.
  var evidence: [String] = []
}
