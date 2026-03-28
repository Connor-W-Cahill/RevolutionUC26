import SwiftUI

// MARK: - Design System Colors (from DESIGN.md)

enum AppTheme {
    // Primary
    static let deepTeal = Color(hex: "1A6B5C")
    static let softTeal = Color(hex: "2D9F8F")
    static let mint = Color(hex: "A8E6CF")

    // Stress Spectrum
    static let stressLow = Color(hex: "A8E6CF")
    static let stressModerate = Color(hex: "FFD93D")
    static let stressElevated = Color(hex: "FF8C42")
    static let stressHigh = Color(hex: "E85D75")

    // Neutrals
    static let background = Color(hex: "F8F9FA")
    static let cardBackground = Color.white
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "6B7280")
    static let divider = Color(hex: "E5E7EB")

    // Accents
    static let calmBlue = Color(hex: "5B9BD5")
    static let softPurple = Color(hex: "8B7EC8")
    static let warmCoral = Color(hex: "F0A1A8")

    // Card styling
    static let cardRadius: CGFloat = 16
    static let cardShadow: CGFloat = 8

    static func stressColor(for category: StressCategory) -> Color {
        switch category {
        case .low: return stressLow
        case .moderate: return stressModerate
        case .high: return stressElevated
        case .veryHigh: return stressHigh
        }
    }

    static func stressTextColor(for category: StressCategory) -> Color {
        switch category {
        case .low: return deepTeal
        case .moderate: return Color(hex: "9A7B00")
        case .high: return Color(hex: "C45F1A")
        case .veryHigh: return Color(hex: "B8344E")
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Card ViewModifier

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: AppTheme.cardShadow, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
