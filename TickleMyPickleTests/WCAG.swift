import SwiftUI
import UIKit

/// WCAG 2.x contrast math for the color tests. Colors are resolved under a
/// trait collection (light by default) and rounded to 8-bit steps, so float
/// noise can't fail an equality check.
enum WCAG {
  /// Minimum for body text (AA).
  static let textMinimum = 4.5
  /// Minimum for large text (18pt+, or 14pt+ bold) and for icons and other
  /// non-text UI that conveys meaning (AA, 1.4.11).
  static let largeTextAndUIMinimum = 3.0

  struct RGB: Equatable {
    let r: Double
    let g: Double
    let b: Double
  }

  static func rgb(
    _ color: Color, in traits: UITraitCollection = UITraitCollection(userInterfaceStyle: .light)
  ) -> RGB {
    let resolved = UIColor(color).resolvedColor(with: traits)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
    func step(_ v: CGFloat) -> Double { (Double(v) * 255).rounded() / 255 }
    return RGB(r: step(r), g: step(g), b: step(b))
  }

  /// `color` drawn at `opacity` over `background`, as it appears on screen.
  static func composite(_ color: RGB, opacity: Double, over background: RGB) -> RGB {
    func mix(_ f: Double, _ b: Double) -> Double { opacity * f + (1 - opacity) * b }
    return RGB(r: mix(color.r, background.r), g: mix(color.g, background.g), b: mix(color.b, background.b))
  }

  /// Contrast ratio between two opaque sRGB colors.
  static func contrast(_ a: RGB, _ b: RGB) -> Double {
    func channel(_ c: Double) -> Double {
      c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    func luminance(_ c: RGB) -> Double {
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
    let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
    return (hi + 0.05) / (lo + 0.05)
  }

  static func contrast(_ a: Color, _ b: Color) -> Double {
    contrast(rgb(a), rgb(b))
  }
}
