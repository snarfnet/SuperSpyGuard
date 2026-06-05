import Foundation
import Network

@MainActor
class NetworkScanner: ObservableObject {
    @Published var discoveredServices: [(name: String, type: String)] = []
    @Published var isScanning = false

    private var browsers: [NWBrowser] = []

    private let serviceTypes = [
        "_http._tcp", "_rtsp._tcp", "_camera._tcp",
        "_airplay._tcp", "_raop._tcp", "_hap._tcp",
        "_ipp._tcp", "_ssh._tcp", "_ftp._tcp", "_daap._tcp"
    ]

    private let suspiciousKeywords = [
        "cam", "camera", "ipcam", "dvr", "nvr", "stream",
        "rtsp", "spy", "hidden", "recorder", "surveillance",
        "cctv", "monitor", "nano", "pinhole", "minispy"
    ]

    func start() {
        discoveredServices = []
        isScanning = true
        for serviceType in serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor in
                    guard let self else { return }
                    for result in results {
                        if case let .service(name, type, _, _) = result.endpoint {
                            if !self.discoveredServices.contains(where: { $0.name == name && $0.type == type }) {
                                self.discoveredServices.append((name: name, type: type))
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

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        isScanning = false
    }

    private func isSuspicious(_ name: String, type: String) -> Bool {
        if type.contains("rtsp") || type.contains("camera") { return true }
        let lower = name.lowercased()
        return suspiciousKeywords.contains { lower.contains($0) }
    }

    func getResults() -> [DetectedItem] {
        discoveredServices.map { service in
            let suspicious = isSuspicious(service.name, type: service.type)
            let cleanType = service.type.replacingOccurrences(of: "._tcp", with: "").replacingOccurrences(of: "_", with: "")
            return DetectedItem(
                phase: .wifi,
                name: service.name,
                detail: "プロトコル: \(cleanType)\(suspicious ? "【盗撮器の可能性】" : "")",
                threatLevel: suspicious ? .high : .low
            )
        }
    }
}
