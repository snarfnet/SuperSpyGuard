import Foundation
import CoreMotion

@MainActor
class MagneticScanner: ObservableObject {
    @Published var fieldStrength: Double = 0
    @Published var isAnomalyDetected = false
    @Published var peakStrength: Double = 0

    private let motionManager = CMMotionManager()
    private var baselineStrength: Double?
    private var readings: [Double] = []
    private let anomalyThreshold: Double = 100

    func start() {
        guard motionManager.isMagnetometerAvailable else { return }
        baselineStrength = nil
        readings = []
        isAnomalyDetected = false
        peakStrength = 0
        motionManager.magnetometerUpdateInterval = 0.05
        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let x = data.magneticField.x, y = data.magneticField.y, z = data.magneticField.z
            let magnitude = sqrt(x*x + y*y + z*z)
            Task { @MainActor in
                self.fieldStrength = magnitude
                if magnitude > self.peakStrength { self.peakStrength = magnitude }
                self.readings.append(magnitude)
                if self.readings.count == 10 {
                    self.baselineStrength = self.readings.reduce(0,+) / 10.0
                }
                if let baseline = self.baselineStrength, abs(magnitude - baseline) > self.anomalyThreshold {
                    self.isAnomalyDetected = true
                }
            }
        }
    }

    func stop() { motionManager.stopMagnetometerUpdates() }

    func getResults() -> [DetectedItem] {
        guard isAnomalyDetected else { return [] }
        return [DetectedItem(
            phase: .magnetic,
            name: "磁場異常を検出",
            detail: String(format: "ピーク %.0f μT（電子機器の存在を示す異常値）", peakStrength),
            threatLevel: peakStrength > 300 ? .high : .medium
        )]
    }
}
