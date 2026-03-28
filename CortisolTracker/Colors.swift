import SwiftUI

extension Color {
    // MARK: - Primary Brand
    static let deepTeal    = Color(red: 0.102, green: 0.420, blue: 0.361)  // #1A6B5C
    static let softTeal    = Color(red: 0.176, green: 0.624, blue: 0.561)  // #2D9F8F
    static let mint        = Color(red: 0.659, green: 0.902, blue: 0.812)  // #A8E6CF

    // MARK: - Stress Spectrum
    static let stressLow      = Color(red: 0.659, green: 0.902, blue: 0.812)  // #A8E6CF — mint green
    static let stressModerate = Color(red: 1.000, green: 0.851, blue: 0.239)  // #FFD93D — warm yellow
    static let stressElevated = Color(red: 1.000, green: 0.549, blue: 0.259)  // #FF8C42 — soft orange
    static let stressHigh     = Color(red: 0.910, green: 0.365, blue: 0.459)  // #E85D75 — rose red

    // MARK: - Accents
    static let calmBlue   = Color(red: 0.357, green: 0.608, blue: 0.835)  // #5B9BD5 — HRV
    static let softPurple = Color(red: 0.545, green: 0.494, blue: 0.784)  // #8B7EC8 — tips/AI
    static let warmCoral  = Color(red: 0.941, green: 0.631, blue: 0.659)  // #F0A1A8 — heart rate
}

// MARK: - StressCategory → brand color
extension StressCategory {
    var brandColor: Color {
        switch self {
        case .low:      return .stressLow
        case .moderate: return .stressModerate
        case .high:     return .stressElevated
        case .veryHigh: return .stressHigh
        }
    }
}
