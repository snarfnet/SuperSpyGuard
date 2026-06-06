import SwiftUI
import CoreBluetooth

@MainActor
class TrackerDetector: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var trackedDevices: [TrackedBLEDevice] = []
    @Published var alerts: [TrackerAlert] = []
    @Published var scanDuration: TimeInterval = 0
    @Published var statusText = "スキャン待機中"

    private var centralManager: CBCentralManager?
    private var deviceMap: [UUID: DeviceRecord] = [:]
    private var scanStartTime: Date?
    private var updateTimer: Timer?

    // Alert thresholds
    private let stalkerThresholdMinutes: Double = 10
    private let suspiciousThresholdMinutes: Double = 5
    private let strongSignalThreshold: Int = -55

    // Known tracker manufacturer patterns (from advertisement data)
    private let trackerPatterns: [String: String] = [
        "tile":       "Tile",
        "smarttag":   "Samsung SmartTag",
        "smart tag":  "Samsung SmartTag",
        "chipolo":    "Chipolo",
        "nutfind":    "Nut Find",
        "nut find":   "Nut Find",
        "trackr":     "TrackR",
        "pebblebee":  "PebbleBee",
        "cube":       "Cube Tracker",
        "airtag":     "AirTag",
        "find my":    "Apple Find My",
    ]

    // Apple company ID for manufacturer data detection
    private let appleCompanyID: UInt16 = 0x004C

    struct DeviceRecord {
        let peripheralID: UUID
        var name: String
        var rssiHistory: [(Date, Int)]
        var firstSeen: Date
        var lastSeen: Date
        var advertisementData: [String: Any]
        var detectedType: String?
        var seenCount: Int
    }

    func start() {
        guard !isScanning else { return }
        isScanning = true
        deviceMap = [:]
        trackedDevices = []
        alerts = []
        scanDuration = 0
        scanStartTime = Date()
        statusText = "Bluetooth起動中..."
        centralManager = CBCentralManager(delegate: self, queue: nil)

        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTracking()
            }
        }
    }

    func stop() {
        centralManager?.stopScan()
        centralManager = nil
        updateTimer?.invalidate()
        updateTimer = nil
        isScanning = false
        statusText = alerts.isEmpty
            ? "追跡デバイスは検出されませんでした"
            : "\(alerts.count)件の追跡疑いデバイスを検出"
    }

    private func updateTracking() {
        guard let startTime = scanStartTime else { return }
        scanDuration = Date().timeIntervalSince(startTime)

        let now = Date()
        var updatedDevices: [TrackedBLEDevice] = []
        var newAlerts: [TrackerAlert] = []

        for (_, record) in deviceMap {
            let duration = record.lastSeen.timeIntervalSince(record.firstSeen)
            let durationMinutes = duration / 60.0
            let avgRSSI = record.rssiHistory.map(\.1).reduce(0, +) / max(record.rssiHistory.count, 1)
            let latestRSSI = record.rssiHistory.last?.1 ?? -100
            let isRecent = now.timeIntervalSince(record.lastSeen) < 30

            // Classify threat level
            let threat: TrackerThreatLevel
            if durationMinutes >= stalkerThresholdMinutes && isRecent {
                threat = .danger
            } else if durationMinutes >= suspiciousThresholdMinutes && isRecent {
                threat = .suspicious
            } else if record.detectedType != nil && isRecent {
                threat = .suspicious
            } else if latestRSSI > strongSignalThreshold && isRecent {
                threat = .nearby
            } else {
                threat = .normal
            }

            let device = TrackedBLEDevice(
                id: record.peripheralID,
                name: record.name.isEmpty ? "不明なデバイス" : record.name,
                detectedType: record.detectedType,
                firstSeen: record.firstSeen,
                lastSeen: record.lastSeen,
                durationSeconds: duration,
                latestRSSI: latestRSSI,
                avgRSSI: avgRSSI,
                seenCount: record.seenCount,
                threatLevel: threat,
                isActive: isRecent
            )
            updatedDevices.append(device)

            // Generate alert for suspicious+
            if threat == .danger || threat == .suspicious {
                let alert = TrackerAlert(
                    deviceID: record.peripheralID,
                    deviceName: device.name,
                    detectedType: record.detectedType,
                    durationMinutes: durationMinutes,
                    avgRSSI: avgRSSI,
                    level: threat
                )
                newAlerts.append(alert)
            }
        }

        // Sort: threats first, then by duration
        trackedDevices = updatedDevices.sorted { a, b in
            if a.threatLevel != b.threatLevel { return a.threatLevel.sortOrder < b.threatLevel.sortOrder }
            return a.durationSeconds > b.durationSeconds
        }
        alerts = newAlerts

        let activeCount = updatedDevices.filter(\.isActive).count
        statusText = "スキャン中 — \(activeCount)台のデバイスを追跡中"
    }

    private func classifyDevice(name: String, advertisementData: [String: Any]) -> String? {
        let lower = name.lowercased()

        // Check name against known tracker patterns
        for (pattern, label) in trackerPatterns {
            if lower.contains(pattern) { return label }
        }

        // Check Apple manufacturer data for potential AirTag/Find My
        if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
           mfgData.count >= 2 {
            let companyID = UInt16(mfgData[0]) | (UInt16(mfgData[1]) << 8)
            if companyID == appleCompanyID && name.isEmpty {
                // Unnamed Apple device broadcasting — could be AirTag or Find My accessory
                return "Apple系トラッカー疑い"
            }
        }

        // Generic tracker keywords
        if lower.contains("track") || lower.contains("find") || lower.contains("tag") || lower.contains("gps") {
            return "トラッカー疑い"
        }

        return nil
    }
}

// MARK: - CBCentralManagerDelegate

extension TrackerDetector: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Allow duplicates to track RSSI changes over time
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            Task { @MainActor in
                self.statusText = "スキャン中 — デバイスを検索中..."
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                     advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let rssi = RSSI.intValue
        let id = peripheral.identifier
        let now = Date()

        guard rssi > -95 && rssi < 0 else { return }

        Task { @MainActor in
            if var record = self.deviceMap[id] {
                // Update existing
                record.lastSeen = now
                record.rssiHistory.append((now, rssi))
                record.seenCount += 1
                if !name.isEmpty && record.name.isEmpty { record.name = name }
                // Keep last 100 RSSI readings
                if record.rssiHistory.count > 100 {
                    record.rssiHistory = Array(record.rssiHistory.suffix(100))
                }
                self.deviceMap[id] = record
            } else {
                // New device
                let type = self.classifyDevice(name: name, advertisementData: advertisementData)
                let record = DeviceRecord(
                    peripheralID: id,
                    name: name,
                    rssiHistory: [(now, rssi)],
                    firstSeen: now,
                    lastSeen: now,
                    advertisementData: advertisementData,
                    detectedType: type,
                    seenCount: 1
                )
                self.deviceMap[id] = record
            }
        }
    }
}

// MARK: - Models

struct TrackedBLEDevice: Identifiable {
    let id: UUID
    let name: String
    let detectedType: String?
    let firstSeen: Date
    let lastSeen: Date
    let durationSeconds: TimeInterval
    let latestRSSI: Int
    let avgRSSI: Int
    let seenCount: Int
    let threatLevel: TrackerThreatLevel
    let isActive: Bool

    var durationText: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        }
        return "\(seconds)秒"
    }

    var signalText: String {
        if latestRSSI > -40 { return "非常に近い" }
        if latestRSSI > -55 { return "近い" }
        if latestRSSI > -70 { return "中程度" }
        return "遠い"
    }
}

enum TrackerThreatLevel: Comparable {
    case normal, nearby, suspicious, danger

    var sortOrder: Int {
        switch self {
        case .danger:     return 0
        case .suspicious: return 1
        case .nearby:     return 2
        case .normal:     return 3
        }
    }

    var label: String {
        switch self {
        case .danger:     return "追跡の疑い"
        case .suspicious: return "要注意"
        case .nearby:     return "近距離"
        case .normal:     return "正常"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .danger:     return AppTheme.neonRed
        case .suspicious: return AppTheme.neonOrange
        case .nearby:     return AppTheme.neonYellow
        case .normal:     return AppTheme.neonGreen
        }
    }
}

struct TrackerAlert: Identifiable {
    let id = UUID()
    let deviceID: UUID
    let deviceName: String
    let detectedType: String?
    let durationMinutes: Double
    let avgRSSI: Int
    let level: TrackerThreatLevel
}
