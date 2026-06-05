import SwiftUI
import AVFoundation
import CoreLocation
import WidgetKit

@MainActor
class ScanCoordinator: NSObject, ObservableObject {
    @Published var appState: AppState = .idle
    @Published var currentPhase: ScanPhase = .magnetic
    @Published var phaseProgress: Double = 0
    @Published var overallProgress: Double = 0
    @Published var detectedItems: [DetectedItem] = []
    @Published var magneticReading: Double = 0
    @Published var microphoneDB: Double = -60
    @Published var showCamera = false
    @Published var locationLabel: String = ""

    let magneticScanner = MagneticScanner()
    let bluetoothScanner = BluetoothScanner()
    let networkScanner = NetworkScanner()
    let microphoneScanner = MicrophoneScanner()
    let ultrasonicScanner = UltrasonicScanner()
    let lightScanner = LightScanner()
    let lensDetector = LensDetector()

    private var scanTask: Task<Void, Never>?
    private let locationManager = CLLocationManager()
    private let phaseDuration: Double = 8.0
    private var micActive = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    var overallThreatLevel: ThreatLevel {
        detectedItems.map(\.threatLevel).max() ?? .safe
    }

    var threatSummary: String {
        let count = detectedItems.filter { $0.threatLevel >= .medium }.count
        if count == 0 { return "不審なデバイス・信号は検出されませんでした" }
        return "\(count)件の注意が必要な項目を検出しました"
    }

    func startScan() {
        scanTask?.cancel()
        detectedItems = []
        appState = .scanning
        overallProgress = 0
        locationLabel = ""
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        scanTask = Task {
            for phase in ScanPhase.allCases {
                if Task.isCancelled { return }
                await runPhase(phase)
            }
            appState = .results
            saveWidgetData()
        }
    }

    func reset() {
        scanTask?.cancel()
        stopAllScanners()
        showCamera = false
        appState = .idle
        overallProgress = 0
        phaseProgress = 0
        detectedItems = []
    }

    private func stopAllScanners() {
        magneticScanner.stop()
        bluetoothScanner.stop()
        networkScanner.stop()
        if micActive {
            microphoneScanner.stop()
            ultrasonicScanner.stop()
            micActive = false
        }
        lightScanner.stop()
        lensDetector.stop()
    }

    private func runPhase(_ phase: ScanPhase) async {
        currentPhase = phase
        phaseProgress = 0

        switch phase {
        case .magnetic:   magneticScanner.start()
        case .infrared:   showCamera = true
        case .wifi:       networkScanner.start()
        case .bluetooth:  bluetoothScanner.start()
        case .microphone:
            microphoneScanner.start()
            micActive = true
        case .ultrasonic:
            if !micActive { ultrasonicScanner.start(); micActive = true }
        case .light:
            lightScanner.start()
            showCamera = true
        case .lens:
            lensDetector.start()
            showCamera = true
        }

        let steps = 50
        let interval = phaseDuration / Double(steps)
        for i in 1...steps {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            phaseProgress = Double(i) / Double(steps)
            let phaseIndex = Double(phase.rawValue)
            overallProgress = (phaseIndex + phaseProgress) / Double(ScanPhase.allCases.count)

            switch phase {
            case .magnetic:    magneticReading = magneticScanner.fieldStrength
            case .microphone:  microphoneDB = microphoneScanner.currentDB
            default: break
            }
        }

        switch phase {
        case .magnetic:
            magneticScanner.stop()
            detectedItems.append(contentsOf: magneticScanner.getResults())
        case .infrared:
            showCamera = false
        case .wifi:
            networkScanner.stop()
            detectedItems.append(contentsOf: networkScanner.getResults())
        case .bluetooth:
            bluetoothScanner.stop()
            detectedItems.append(contentsOf: bluetoothScanner.getResults())
        case .microphone:
            microphoneScanner.stop()
            detectedItems.append(contentsOf: microphoneScanner.getResults())
        case .ultrasonic:
            ultrasonicScanner.stop()
            micActive = false
            detectedItems.append(contentsOf: ultrasonicScanner.getResults())
        case .light:
            lightScanner.stop()
            showCamera = false
            detectedItems.append(contentsOf: lightScanner.getResults())
        case .lens:
            lensDetector.stop()
            showCamera = false
            detectedItems.append(contentsOf: lensDetector.getResults())
        }
    }

    func makeSession(notes: String = "") -> ScanSession {
        ScanSession(id: UUID(), date: Date(), items: detectedItems,
                    locationLabel: locationLabel, notes: notes)
    }

    func saveWidgetData() {
        struct WidgetSyncData: Codable {
            let lastScanDate: Date
            let threatLevel: Int
            let threatCount: Int
            let locationLabel: String
        }
        let data = WidgetSyncData(
            lastScanDate: Date(),
            threatLevel: overallThreatLevel.rawValue,
            threatCount: detectedItems.filter { $0.threatLevel >= .medium }.count,
            locationLabel: locationLabel
        )
        if let encoded = try? JSONEncoder().encode(data) {
            let defaults = UserDefaults(suiteName: "group.com.tokyonasu.SuperSpyGuard") ?? .standard
            defaults.set(encoded, forKey: "widgetData")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension ScanCoordinator: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            Task { @MainActor in
                if let p = placemarks?.first {
                    self?.locationLabel = [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
