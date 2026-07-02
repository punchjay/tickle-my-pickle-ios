import SwiftUI

/// Single court row: numbered badge (Nearby tab only), name, amenity badges,
/// address, rating, open/closed status, a directions link, and a star toggle.
/// Ported from the original app's `CourtList` row rendering.
struct CourtRowView: View {
  let court: Court
  let number: Int?
  let selected: Bool
  let isFavorite: Bool
  let onSelect: () -> Void
  let onToggleFavorite: () -> Void

  private var highConfidenceTags: [Tag] {
    // Phase 1: show high-confidence amenity guesses only (labels, no
    // filtering), so the numbered pins stay aligned with the list.
    Amenities.inferAmenities(for: court).filter { $0.confidence == .high }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      if let number {
        ZStack {
          Circle().fill(selected ? Palette.midnight : Palette.terracotta)
          Text("\(number)")
            .font(AppFont.bodyBold(13))
            .foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(court.name)
          .font(AppFont.display(20))
          .foregroundStyle(Semantic.text)
          .lineLimit(1)

        if !highConfidenceTags.isEmpty {
          HStack(spacing: 4) {
            ForEach(highConfidenceTags, id: \.kind) { tag in
              AmenityBadgeView(kind: tag.kind)
            }
          }
          .accessibilityLabel(AppCopy.Amenities.disclaimer)
        }

        if !court.address.isEmpty {
          Text(court.address)
            .font(AppFont.body(13))
            .foregroundStyle(Semantic.textMuted)
            .lineLimit(1)
        }

        if let rating = court.rating {
          Text(ratingLine(rating))
            .font(AppFont.bodyMedium(13))
            .foregroundStyle(Palette.marigold)
        }

        if let isOpen = court.isOpen {
          Text(isOpen ? AppCopy.CourtList.openNow : AppCopy.CourtList.closed)
            .font(AppFont.bodyMedium(13))
            .foregroundStyle(isOpen ? Semantic.open : Semantic.closed)
        }

        Link(destination: directionsURL) {
          Text(AppCopy.CourtList.directions)
            .font(AppFont.bodyMedium(13))
            .foregroundStyle(Semantic.link)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
      }

      Spacer(minLength: 0)

      Button(action: onToggleFavorite) {
        Image(systemName: isFavorite ? "star.fill" : "star")
          .foregroundStyle(isFavorite ? Semantic.primary : Semantic.textMuted)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isFavorite ? AppCopy.CourtList.unsave : AppCopy.CourtList.save)
    }
    .padding(12)
    .background(Semantic.card)
    .overlay(
      RoundedRectangle(cornerRadius: Radii.md)
        .stroke(selected ? Palette.terracotta : Semantic.border, lineWidth: 2),
    )
    .clipShape(RoundedRectangle(cornerRadius: Radii.md))
    .contentShape(Rectangle())
    .onTapGesture(perform: onSelect)
  }

  private func ratingLine(_ rating: Double) -> String {
    let base = String(format: "★ %.1f", rating)
    guard let count = court.userRatingCount else { return base }
    return "\(base)  (\(count))"
  }

  private var directionsURL: URL {
    let name = court.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? court.name
    let id = court.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? court.id
    return URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(name)&destination_place_id=\(id)")!
  }
}
