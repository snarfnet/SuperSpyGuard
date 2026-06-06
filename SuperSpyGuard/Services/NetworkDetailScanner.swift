import Foundation
import Network
@preconcurrency import CoreBluetooth
import Darwin

struct NetworkDevice: Identifiable {
    let id = UUID()
    let name: String
    let serviceType: String
    let manufacturer: String
    let threatLevel: ThreatLevel
    let detail: String
}

struct NetworkInfo {
    let localIP: String
    let interfaceName: String
}

@MainActor
class NetworkDetailScanner: NSObject, ObservableObject {
    @Published var devices: [NetworkDevice] = []
    @Published var networkInfo: NetworkInfo?
    @Published var isScanning = false
    @Published var bleDevicesDetail: [(name: String, manufacturer: String, rssi: Int)] = []

    private var browsers: [NWBrowser] = []
    private var centralManager: CBCentralManager?

    private let serviceTypes = [
        "_http._tcp", "_rtsp._tcp", "_camera._tcp", "_airplay._tcp",
        "_raop._tcp", "_hap._tcp", "_ipp._tcp", "_ssh._tcp",
        "_ftp._tcp", "_daap._tcp", "_smb._tcp", "_afpovertcp._tcp"
    ]

    private let suspiciousKeywords = [
        "cam", "camera", "ipcam", "dvr", "nvr", "rtsp", "spy",
        "hidden", "recorder", "surveillance", "cctv", "monitor", "nano"
    ]

    // OUI (Organizationally Unique Identifier) - first 3 bytes of MAC
    // Partial database of known IoT/camera manufacturers
    private let ouiDatabase: [String: String] = [
        "00:0C:E7": "Hikvision", "C0:56:E3": "Hikvision",
        "28:57:BE": "Dahua", "3C:EF:8C": "Dahua",
        "00:23:63": "Axis Comm", "AC:CC:8E": "Axis Comm",
        "B4:A3:82": "Reolink", "EC:71:DB": "Reolink",
        "2C:AA:8E": "TP-Link", "50:C7:BF": "TP-Link",
        "00:50:C2": "IEEE", "DC:A6:32": "Raspberry Pi",
        "B8:27:EB": "Raspberry Pi", "E4:5F:01": "Raspberry Pi",
        "00:E0:4C": "Realtek", "A4:CF:12": "Espressif (IoT)",
        "84:F3:EB": "Espressif (IoT)", "30:AE:A4": "Espressif (IoT)",
        "CC:50:E3": "Espressif (IoT)", "10:52:1C": "Espressif (IoT)",
    ]

    func start() {
        devices = []
        bleDevicesDetail = []
        isScanning = true
        networkInfo = getLocalNetworkInfo()
        startBonjourScan()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        centralManager?.stopScan()
        centralManager = nil
        isScanning = false
    }

    private func startBonjourScan() {
        for serviceType in serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor in
                    guard let self else { return }
                    for result in results {
                        if case let .service(name, type, _, _) = result.endpoint {
                            if !self.devices.contains(where: { $0.name == name && $0.serviceType == type }) {
                                let suspicious = self.isSuspicious(name, type: type)
                                let cleanType = type.replacingOccurrences(of: "._tcp", with: "").replacingOccurrences(of: "_", with: "").uppercased()
                                let device = NetworkDevice(
                                    name: name,
                                    serviceType: cleanType,
                                    manufacturer: self.guessManufacturer(from: name),
                                    threatLevel: suspicious ? .high : .low,
                                    detail: "サービス: \(cleanType)\(suspicious ? " 【要注意】" : "")"
                                )
                                self.devices.append(device)
                            }
                        }
                    }
                }
            }
            browser.stateUpdateHandler = { _ in }
            browser.start(queue: .main)
            browsers.append(browser)
        }
    }

    private func isSuspicious(_ name: String, type: String) -> Bool {
        if type.contains("rtsp") || type.contains("camera") { return true }
        let lower = name.lowercased()
        return suspiciousKeywords.contains { lower.contains($0) }
    }

    private func guessManufacturer(from name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("hikvision") || lower.contains("hikam") { return "Hikvision" }
        if lower.contains("dahua") { return "Dahua" }
        if lower.contains("axis") { return "Axis" }
        if lower.contains("reolink") { return "Reolink" }
        if lower.contains("apple") { return "Apple" }
        if lower.contains("samsung") { return "Samsung" }
        if lower.contains("tp-link") || lower.contains("tplink") { return "TP-Link" }
        if lower.contains("raspberry") { return "Raspberry Pi" }
        return "不明"
    }

    func getLocalNetworkInfo() -> NetworkInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) && (flags & IFF_LOOPBACK) == 0 {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len),
                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: hostname)
                let name = String(cString: ptr.pointee.ifa_name)
                if ip.hasPrefix("192.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                    return NetworkInfo(localIP: ip, interfaceName: name)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return nil
    }
}

extension NetworkDetailScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                     advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "不明"
        let rssi = RSSI.intValue
        var manufacturer = "不明"
        if let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, mfgData.count >= 2 {
            let companyId = UInt16(mfgData[0]) | (UInt16(mfgData[1]) << 8)
            // Common Bluetooth company IDs
            switch companyId {
            case 0x004C: manufacturer = "Apple"
            case 0x0075: manufacturer = "Samsung"
            case 0x0006: manufacturer = "Microsoft"
            case 0x000F: manufacturer = "Broadcom"
            case 0x0059: manufacturer = "Nordic Semi"
            case 0x02FF: manufacturer = "Espressif"
            default: manufacturer = String(format: "ID:0x%04X", companyId)
            }
        }
        Task { @MainActor in
            if rssi > -90 && !self.bleDevicesDetail.contains(where: { $0.name == name }) {
                self.bleDevicesDetail.append((name: name, manufacturer: manufacturer, rssi: rssi))
            }
        }
    }
}
