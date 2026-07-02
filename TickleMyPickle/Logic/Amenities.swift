/// Amenity tagging heuristic, ported verbatim from the original app's
/// `amenities.ts`. The Places API (New) fields requested carry no structured
/// indoor/outdoor/amenity signal, so every tag here is an *inference* from
/// the listing name and coarse Place `types`. Tags carry a confidence so the
/// UI can show only `high`-confidence guesses by default and never silently
/// mislabel a court.
enum Amenities {
  // Keyword tables -- kept here, in one place, so they're tunable and
  // testable. Matched case-insensitively as substrings of the listing name.
  private static let indoorHigh = [
    "indoor",
    "fieldhouse",
    "rec center",
    "recreation center",
    "ymca",
    "athletic club",
    "sportsplex",
    "gym",
    "arena",
  ]
  private static let indoorLow = ["club"] // weak: a "club" is often, but not always, indoor
  private static let outdoorLow = ["tennis center"] // weak: tennis centers are usually outdoor
  private static let lighted = ["lighted", "lights"]
  private static let privateKeywords = ["club", "academy"] // suppresses the "free" guess

  private static func rank(_ confidence: Confidence) -> Int { confidence.rawValue }

  /// Derive the displayable amenity tags for a court. Indoor and outdoor are
  /// mutually exclusive: if both match, the higher-confidence one wins, and a
  /// tie yields neither (better to show nothing than guess wrong).
  static func inferAmenities(for court: Court) -> [Tag] {
    let name = court.name.lowercased()
    let types = court.types ?? []
    let isParkType = types.contains("park")
    func has(_ keywords: [String]) -> Bool { keywords.contains { name.contains($0) } }

    var indoor: Confidence?
    if has(indoorHigh) {
      indoor = .high
    } else if has(indoorLow) {
      indoor = .low
    }

    var outdoor: Confidence?
    if name.contains("outdoor") || isParkType || name.contains("park") {
      outdoor = .high
    } else if has(outdoorLow) {
      outdoor = .low
    }

    // Resolve the indoor/outdoor conflict by confidence; drop both on a tie.
    if let indoorConfidence = indoor, let outdoorConfidence = outdoor {
      if rank(indoorConfidence) > rank(outdoorConfidence) {
        outdoor = nil
      } else if rank(outdoorConfidence) > rank(indoorConfidence) {
        indoor = nil
      } else {
        indoor = nil
        outdoor = nil
      }
    }

    var tags: [Tag] = []
    if let indoor { tags.append(Tag(kind: .indoor, confidence: indoor)) }
    if let outdoor { tags.append(Tag(kind: .outdoor, confidence: outdoor)) }
    if has(lighted) { tags.append(Tag(kind: .lighted, confidence: .high)) }
    // Free: a public park, but not a private club/academy.
    if isParkType && !has(privateKeywords) {
      tags.append(Tag(kind: .free, confidence: .high))
    }

    return tags
  }
}
