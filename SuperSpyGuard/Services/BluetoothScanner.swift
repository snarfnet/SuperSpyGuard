import Foundation
@preconcurrency import CoreBluetooth

@MainActor
class BluetoothScanner: NSObject, ObservableObject {
    @Published var discoveredDevices: [(name: String, rssi: Int, id: UUID)] = []
    @Published var isScanning = false

    private var centralManager: CBCentralManager?
    private var foundDevices: Set<UUID> = []

    private let suspiciousPatterns = [
        "cam", "camera", "spy", "hidden", "wifi_cam", "ipcam", "ip_cam",
        "mini_cam", "hd_cam", "recorder", "mic", "bug", "tracker", "listen",
        "monitor", "cctv", "dvr", "nvr", "nano", "pinhole"
    ]

    func start() {
        discoveredDevices = []
        foundDevices = []
        isScanning = true
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        centralManager?.stopScan()
        centralManager = nil
        isScanning = false
    }

    private func isSuspicious(_ name: String) -> Bool {
        let lower = name.lowercased()
        return suspiciousPatterns.contains { lower.contains($0) }
    }

    func getResults() -> [DetectedItem] {
        discoveredDevices.map { device in
            let suspicious = isSuspicious(device.name)
            let name = device.name.isEmpty ? "不明なデバイス" : device.name
            let level: ThreatLevel = suspicious ? .high : (device.rssi > -50 ? .low : .safe)
            return DetectedItem(
                phase: .bluetooth,
                name: name,
                detail: "信号強度: \(device.rssi) dBm\(suspicious ? "【要注意ワード含む】" : "")",
                threatLevel: level
            )
        }
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                     advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let rssi = RSSI.intValue
        let id = peripheral.identifier
        Task { @MainActor in
            if !self.foundDevices.contains(id) && rssi > -90 {
                self.foundDevices.insert(id)
                self.discoveredDevices.append((name: name, rssi: rssi, id: id))
            }
        }
    }
}
