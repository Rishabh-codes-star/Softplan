import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// One color family = three shades used together on a bar:
/// tinted `fill` for the background, saturated `accent` for dates/description,
/// deep `ink` for the title.
struct PaletteColor: Identifiable, Hashable {
    let id: String
    let name: String
    let fill: Color
    let accent: Color
    let ink: Color
}

/// Muted, earthy families sampled from the reference poster.
enum Palette {
    static let colors: [PaletteColor] = [
        .init(id: "brick",      name: "Brick",      fill: Color(hex: 0xF2C9BD), accent: Color(hex: 0xC15B42), ink: Color(hex: 0x542016)),
        .init(id: "terracotta", name: "Terracotta", fill: Color(hex: 0xF7D4B7), accent: Color(hex: 0xCE6A2A), ink: Color(hex: 0x5C2B0C)),
        .init(id: "mustard",    name: "Mustard",    fill: Color(hex: 0xF2DDA4), accent: Color(hex: 0xB8892A), ink: Color(hex: 0x59430A)),
        .init(id: "olive",      name: "Olive",      fill: Color(hex: 0xE3E3AF), accent: Color(hex: 0x8F8F3D), ink: Color(hex: 0x3F3F12)),
        .init(id: "sage",       name: "Sage",       fill: Color(hex: 0xD7E2C8), accent: Color(hex: 0x7E9865), ink: Color(hex: 0x34432A)),
        .init(id: "forest",     name: "Forest",     fill: Color(hex: 0xC9DECC), accent: Color(hex: 0x4C7A52), ink: Color(hex: 0x1C3A21)),
        .init(id: "teal",       name: "Teal",       fill: Color(hex: 0xC2E2DF), accent: Color(hex: 0x2F8880), ink: Color(hex: 0x0F3B36)),
        .init(id: "navy",       name: "Navy",       fill: Color(hex: 0xC7D8E9), accent: Color(hex: 0x30608F), ink: Color(hex: 0x12293F)),
        .init(id: "slate",      name: "Slate",      fill: Color(hex: 0xD0D7EB), accent: Color(hex: 0x5D6D9E), ink: Color(hex: 0x232C4B)),
        .init(id: "dustypink",  name: "Dusty Pink", fill: Color(hex: 0xF2CBD9), accent: Color(hex: 0xC26E8F), ink: Color(hex: 0x552336)),
        .init(id: "mauve",      name: "Mauve",      fill: Color(hex: 0xE4CCDC), accent: Color(hex: 0x985F80), ink: Color(hex: 0x421F35)),
        .init(id: "brown",      name: "Brown",      fill: Color(hex: 0xE2CDB9), accent: Color(hex: 0x8B5B33), ink: Color(hex: 0x3B2310)),
        .init(id: "red",        name: "Red",        fill: Color(hex: 0xF4C3BE), accent: Color(hex: 0xCE3D34), ink: Color(hex: 0x5C1512)),
        .init(id: "taupe",      name: "Taupe",      fill: Color(hex: 0xDDD5C9), accent: Color(hex: 0x8D8172), ink: Color(hex: 0x3B342B)),
    ]

    static func color(for id: String) -> PaletteColor {
        colors.first { $0.id == id } ?? colors[0]
    }

    /// Auto-assign: the family used least so far. `min(by:)` keeps the first of
    /// equal elements, so ties fall back to palette order on their own.
    static func leastUsedId(in events: [PlanEvent]) -> String {
        var counts: [String: Int] = [:]
        for event in events { counts[event.paletteId, default: 0] += 1 }
        return colors.min { (counts[$0.id] ?? 0) < (counts[$1.id] ?? 0) }?.id ?? colors[0].id
    }
}

/// Shared layout + chrome constants. Vertical structure mirrors the Figma
/// frames: wordmark, big year, month-label row, then day gridlines running
/// the full canvas height, with bars hanging just below the label row.
enum UI {
    static let barHeight: CGFloat = 84
    static let rowGap: CGFloat = 14
    static let barCorner: CGFloat = 22
    static let minBarWidth: CGFloat = 26

    static let contentLeading: CGFloat = 40
    static let wordmarkTop: CGFloat = 36
    static let wordmarkLogoHeight: CGFloat = 34
    static let wordmarkLogoGap: CGFloat = 12
    static let gridLabelBaseline: CGFloat = 162
    static let majorTickTop: CGFloat = 166
    static let gridLineTop: CGFloat = 190
    static let barsTop: CGFloat = 212
    static let timelineBarsTop: CGFloat = barsTop - gridLineTop

    static let canvasBackground = Color.white
    static let todayRed = Color(hex: 0xE0342B)
    static let gridMinor = Color(hex: 0xCDCDD1)
    static let gridMajor = Color(hex: 0x8E8E93)
    static let labelPrimary = Color(hex: 0x1B1B1E)
    /// Darker than the system secondary grey on purpose: at 5.1:1 on white it
    /// clears WCAG AA for the small type it is used on.
    static let labelSecondary = Color(hex: 0x6E6E73)
    static let controlBorder = Color(hex: 0xD9D9DE)
    static let inputFill = Color(hex: 0xF4F4F5)
    static let inputBorder = Color(hex: 0xE5E5E9)
}
