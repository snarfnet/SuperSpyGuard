import SwiftUI
import Foundation

// MARK: - Scan Phase

enum ScanPhase: Int, CaseIterable {
    case magnetic = 0
    case infrared = 1
    case wifi = 2
    case bluetooth = 3
    case microphone = 4
    case ultrasonic = 5
    case light = 6
    case lens = 7

    var name: String {
        switch self {
        case .magnetic:    return "磁力スキャン"
        case .infrared:    return "赤外線スキャン"
        case .wifi:        return "Wi-Fiスキャン"
        case .bluetooth:   return "Bluetoothスキャン"
        case .microphone:  return "マイク盗聴検出"
        case .ultrasonic:  return "超音波スキャン"
        case .light:       return "光源スキャン"
        case .lens:        return "AIレンズ検出"
        }
    }

    var shortName: String {
        switch self {
        case .magnetic:    return "磁力"
        case .infrared:    return "赤外線"
        case .wifi:        return "Wi-Fi"
        case .bluetooth:   return "BLE"
        case .microphone:  return "マイク"
        case .ultrasonic:  return "超音波"
        case .light:       return "光源"
        case .lens:        return "AIレンズ"
        }
    }

    var icon: String {
        switch self {
        case .magnetic:    return "waveform.circle.fill"
        case .infrared:    return "eye.circle.fill"
        case .wifi:        return "wifi.circle.fill"
        case .bluetooth:   return "antenna.radiowaves.left.and.right.circle.fill"
        case .microphone:  return "mic.circle.fill"
        case .ultrasonic:  return "waveform.badge.exclamationmark"
        case .light:       return "lightbulb.circle.fill"
        case .lens:        return "camera.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .magnetic:    return AppTheme.neonGreen
        case .infrared:    return AppTheme.neonRed
        case .wifi:        return AppTheme.neonBlue
        case .bluetooth:   return AppTheme.neonCyan
        case .microphone:  return AppTheme.neonOrange
        case .ultrasonic:  return AppTheme.neonPurple
        case .light:       return AppTheme.neonYellow
        case .lens:        return Color(red: 0.0, green: 0.9, blue: 0.9)
        }
    }

    var description: String {
        switch self {
        case .magnetic:    return "電子機器の磁場異常を検出中..."
        case .infrared:    return "赤外線LEDを検出中..."
        case .wifi:        return "ネットワーク機器を検索中..."
        case .bluetooth:   return "BLEデバイスを検索中..."
        case .microphone:  return "音響異常・盗聴器を検出中..."
        case .ultrasonic:  return "超音波信号を解析中..."
        case .light:       return "不審な光源を検出中..."
        case .lens:        return "AIがレンズ反射パターンを解析中..."
        }
    }
}

// MARK: - Threat Level

enum ThreatLevel: Int, Comparable, Codable {
    case safe = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .safe:   return "安全"
        case .low:    return "低"
        case .medium: return "注意"
        case .high:   return "危険"
        }
    }

    var labelEn: String {
        switch self {
        case .safe:   return "SAFE"
        case .low:    return "LOW"
        case .medium: return "CAUTION"
        case .high:   return "DANGER"
        }
    }

    var color: Color {
        switch self {
        case .safe:   return AppTheme.neonGreen
        case .low:    return AppTheme.neonBlue
        case .medium: return AppTheme.neonYellow
        case .high:   return AppTheme.neonRed
        }
    }
}

// MARK: - Detected Item

struct DetectedItem: Identifiable, Codable {
    let id: UUID
    let phaseRaw: Int
    let name: String
    let detail: String
    let threatLevel: ThreatLevel

    init(phase: ScanPhase, name: String, detail: String, threatLevel: ThreatLevel) {
        self.id = UUID()
        self.phaseRaw = phase.rawValue
        self.name = name
        self.detail = detail
        self.threatLevel = threatLevel
    }

    var phase: ScanPhase { ScanPhase(rawValue: phaseRaw) ?? .magnetic }
}

// MARK: - Scan Session (History)

struct ScanSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let items: [DetectedItem]
    let locationLabel: String
    let notes: String

    var overallThreatLevel: ThreatLevel {
        items.map(\.threatLevel).max() ?? .safe
    }

    var threatCount: Int {
        items.filter { $0.threatLevel >= .medium }.count
    }
}

// MARK: - Checklist

struct ChecklistItem: Identifiable, Codable {
    let id: UUID
    var label: String
    var isChecked: Bool
    var isCustom: Bool

    init(label: String, isChecked: Bool = false, isCustom: Bool = false) {
        self.id = UUID()
        self.label = label
        self.isChecked = isChecked
        self.isCustom = isCustom
    }
}

// MARK: - App State

enum AppState {
    case idle, scanning, results
}
