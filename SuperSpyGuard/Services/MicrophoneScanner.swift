import Foundation
import AVFoundation

@MainActor
class MicrophoneScanner: ObservableObject {
    @Published var currentDB: Double = -60
    @Published var peakDB: Double = -60
    @Published var isAnomalyDetected = false

    private var audioEngine: AVAudioEngine?
    private var baselineDB: Double?
    private var readings: [Double] = []
    private let anomalyThresholdDelta: Double = 25 // dB above baseline

    func start() {
        currentDB = -60
        peakDB = -60
        isAnomalyDetected = false
        readings = []
        baselineDB = nil

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let db = self.calculateDB(buffer: buffer)
            Task { @MainActor in
                self.currentDB = db
                if db > self.peakDB { self.peakDB = db }
                self.readings.append(db)
                if self.readings.count == 20 {
                    self.baselineDB = self.readings.reduce(0,+) / Double(self.readings.count)
                }
                if let baseline = self.baselineDB, db > baseline + self.anomalyThresholdDelta, db > -30 {
                    self.isAnomalyDetected = true
                }
            }
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("MicrophoneScanner error: \(error)")
        }
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func calculateDB(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return -60 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return -60 }
        var sum: Float = 0
        for i in 0..<frameLength { sum += channelData[i] * channelData[i] }
        let rms = sqrt(sum / Float(frameLength))
        let db = rms > 0 ? Double(20 * log10(rms)) : -60
        return max(-60, min(0, db))
    }

    func getResults() -> [DetectedItem] {
        guard isAnomalyDetected else { return [] }
        return [DetectedItem(
            phase: .microphone,
            name: "音響異常を検出",
            detail: String(format: "ピーク %.0f dB（通常より大幅に高い音量を検出）", peakDB),
            threatLevel: .medium
        )]
    }
}
