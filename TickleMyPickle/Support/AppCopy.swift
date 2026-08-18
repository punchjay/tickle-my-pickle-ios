/// Centralized UI copy -- single source of truth for user-facing strings.
/// Ported verbatim from the original app's `appData.ts`.
enum AppCopy {
  enum App {
    static let wordmark = "Tickle My Pickle"
    static let tagline = "Find pickleball courts near you"
  }

  enum Search {
    static let placeholder = "Search City, ZIP, or Hood"
    static let submitLabel = "Search"
    static let inputLabel = "Search location"
    static let nearMe = "Near me"
  }

  enum CourtList {
    /// "1 pickleball court nearby" / "3 pickleball courts nearby"
    static func heading(_ count: Int) -> String {
      "\(count) pickleball \(count == 1 ? "court" : "courts") nearby"
    }
    static let openNow = "Open now"
    static let closed = "Closed"
    static let directions = "Directions"
    static let nearbyTab = "Nearby"
    static let savedTab = "Saved"
    static let save = "Save court"
    static let unsave = "Remove from saved"
    static let emptySaved = "No saved courts yet — tap the star on a court to save it."
  }

  enum Amenities {
    static let indoor = "Indoor"
    static let outdoor = "Outdoor"
    static let lighted = "Lighted"
    static let free = "Free"
    static let disclaimer = "Tags are best guesses from the listing name"

    static func label(for kind: AmenityKind) -> String {
      switch kind {
      case .indoor: return indoor
      case .outdoor: return outdoor
      case .lighted: return lighted
      case .free: return free
      }
    }
  }

  /// Free-text query sent to the Places text search.
  static let searchQuery = "pickleball court"

  /// Fallback name when a Place has no displayName.
  static let unknownCourt = "Unknown court"

  enum Errors {
    static let missingApiKey =
      "Add a real key to Secrets.xcconfig and rebuild."
    static let mapsLoadFailed = "Failed to load Google Maps. Check your API key."
    static let noCourtsFound = "No pickleball courts found nearby. Try a different location."
    static let searchFailed = "Search failed. Please try again."
    static let locationNotFound = "Could not find that location. Try again."
    static let geolocationDenied = "Location access denied. Enter a zip code instead."
  }
}
