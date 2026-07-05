import SwiftUI
import UIKit

/// Font helpers mirroring the original theme's `fonts` tokens (display =
/// Bebas Neue, body = DM Sans, accent = Fredoka). The real .ttf files live in
/// `Resources/Fonts/` and are registered via Info.plist `UIAppFonts` (see
/// `project.yml`). Each helper still falls back to a `.rounded`-design system
/// font if a face fails to register, so the app looks intentional rather than
/// defaulting to plain system text.
enum AppFont {
  private static func isRegistered(_ name: String) -> Bool {
    UIFont(name: name, size: 12) != nil
  }

  static func display(_ size: CGFloat) -> Font {
    isRegistered("BebasNeue-Regular")
      ? .custom("BebasNeue-Regular", size: size)
      : .system(size: size, weight: .bold, design: .rounded)
  }

  static func body(_ size: CGFloat) -> Font {
    isRegistered("DMSans-Regular")
      ? .custom("DMSans-Regular", size: size)
      : .system(size: size, weight: .regular, design: .rounded)
  }

  static func bodyMedium(_ size: CGFloat) -> Font {
    isRegistered("DMSans-Medium")
      ? .custom("DMSans-Medium", size: size)
      : .system(size: size, weight: .medium, design: .rounded)
  }

  static func bodyBold(_ size: CGFloat) -> Font {
    isRegistered("DMSans-Bold")
      ? .custom("DMSans-Bold", size: size)
      : .system(size: size, weight: .bold, design: .rounded)
  }

  static func accent(_ size: CGFloat) -> Font {
    isRegistered("Fredoka-SemiBold")
      ? .custom("Fredoka-SemiBold", size: size)
      : .system(size: size, weight: .semibold, design: .rounded)
  }
}
