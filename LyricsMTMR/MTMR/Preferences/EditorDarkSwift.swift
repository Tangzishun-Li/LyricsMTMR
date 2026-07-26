//
//  EditorDarkSwift.swift
//  LyricsMTMR
//
//  SwiftUI Color / NSColor palette shared by all editor subviews.
//  Mirrors the AppKit EditorDark enum (defined in ElementPaletteView.swift)
//  plus SwiftUI-side dynamic colors.
//

import SwiftUI

enum EditorColors {
    // ── NSColor (AppKit side) ──
    static let bg = NSColor(srgbRed: 0.071, green: 0.063, blue: 0.090, alpha: 1)
    static let sidebar = NSColor(srgbRed: 0.047, green: 0.040, blue: 0.066, alpha: 1)
    static let card = NSColor(srgbRed: 0.145, green: 0.126, blue: 0.180, alpha: 1)
    static let stripBg = NSColor(srgbRed: 0.035, green: 0.030, blue: 0.050, alpha: 1)
    static let inset = NSColor(white: 0, alpha: 0.26)
    static let accent = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1)
    static let accentDeep = NSColor(srgbRed: 0.95, green: 0.36, blue: 0.26, alpha: 1)
    static let mint = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1)
    static let textPrimary = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    static let textSecondary = NSColor(srgbRed: 0.66, green: 0.63, blue: 0.72, alpha: 1)
    static let textTertiary = NSColor(srgbRed: 0.45, green: 0.42, blue: 0.52, alpha: 1)
    static let hairline = NSColor(white: 1, alpha: 0.07)
    static let hairlineStrong = NSColor(white: 1, alpha: 0.14)
    static let hoverFill = NSColor(white: 1, alpha: 0.06)
    static let selectedFill = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 0.12)

    // ── SwiftUI Color (SwiftUI side) ──
    static let bgSwift = Color(nsColor: bg)
    static let sidebarSwift = Color(nsColor: sidebar)
    static let cardSwift = Color(nsColor: card)
    static let stripBgSwift = Color(nsColor: stripBg)
    static let accentSwift = Color(nsColor: accent)
    static let accentDeepSwift = Color(nsColor: accentDeep)
    static let mintSwift = Color(nsColor: mint)
    static let textPrimarySwift = Color(nsColor: textPrimary)
    static let textSecondarySwift = Color(nsColor: textSecondary)
    static let textTertiarySwift = Color(nsColor: textTertiary)
    static let hairlineSwift = Color(nsColor: hairline)
    static let hairlineStrongSwift = Color(nsColor: hairlineStrong)
    static let hoverFillSwift = Color(nsColor: hoverFill)
    static let selectedFillSwift = Color(nsColor: selectedFill)
}
