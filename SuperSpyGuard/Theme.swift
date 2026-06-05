import SwiftUI

enum AppTheme {
    static let background   = Color(red: 0.04, green: 0.06, blue: 0.04)
    static let surface      = Color(red: 0.08, green: 0.11, blue: 0.08)
    static let surfaceHigh  = Color(red: 0.12, green: 0.16, blue: 0.12)

    static let neonGreen    = Color(red: 0.12, green: 1.0,  blue: 0.32)
    static let neonRed      = Color(red: 1.0,  green: 0.15, blue: 0.15)
    static let neonBlue     = Color(red: 0.15, green: 0.55, blue: 1.0)
    static let neonCyan     = Color(red: 0.0,  green: 0.9,  blue: 0.9)
    static let neonOrange   = Color(red: 1.0,  green: 0.55, blue: 0.0)
    static let neonPurple   = Color(red: 0.7,  green: 0.1,  blue: 1.0)
    static let neonYellow   = Color(red: 1.0,  green: 0.9,  blue: 0.0)
    static let gold         = Color(red: 1.0,  green: 0.8,  blue: 0.2)

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.55)

    static let bodyFont    = Font.system(size: 14, design: .monospaced)
    static let labelFont   = Font.system(size: 12, weight: .bold, design: .monospaced)
    static let titleFont   = Font.system(size: 28, weight: .black, design: .rounded)
}
