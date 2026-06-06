import Foundation
@preconcurrency import AVFoundation
import Accelerate

@MainActor
class UltrasonicScanner: ObservableObject {
    @Published var highFrequencyLevel: Double = 0
    @Published var isAnomalyDetected = false
    @Published var detectedFrequency: Double = 0

    private var audioEngine: AVAudioEngine?
    private let targetMinHz: Double = 15000 // 15kHz以上を監視

    func start() {
        highFrequencyLevel = 0
        isAnomalyDetected = false
        detectedFrequency = 0

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let bufferSize: AVAudioFrameCount = 4096

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            var real = [Float](repeating: 0, count: frameCount)
            var imag = [Float](repeating: 0, count: frameCount)
            real = Array(UnsafeBufferPointer(start: channelData, count: frameCount))

            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    let log2n = vDSP_Length(log2(Float(frameCount)))
                    guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2)) else { return }
                    vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_destroy_fftsetup(fftSetup)

                    var magnitudes = [Float](repeating: 0, count: frameCount/2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount/2))

                    let binHz = sampleRate / Double(frameCount)
                    let startBin = Int(self.targetMinHz / binHz)
                    let endBin = min(frameCount/2 - 1, startBin + Int(4000 / binHz))

                    if startBin < endBin {
                        let highFreqSlice = magnitudes[startBin...endBin]
                        let maxMag = highFreqSlice.max() ?? 0
                        let level = Double(maxMag)

                        if let maxIdx = highFreqSlice.indices.max(by: { highFreqSlice[$0] < highFreqSlice[$1] }) {
                            let freq = Double(maxIdx) * binHz
                            Task { @MainActor in
                                self.highFrequencyLevel = level
                                if level > 100 {
                                    self.isAnomalyDetected = true
                                    self.detectedFrequency = freq
                                }
                            }
                        }
                    }
                }
            }
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("UltrasonicScanner error: \(error)")
        }
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func getResults() -> [DetectedItem] {
        guard isAnomalyDetected else { return [] }
        return [DetectedItem(
            phase: .ultrasonic,
            name: "超音波信号を検出",
            detail: String(format: "%.0f Hz付近に不審な高周波信号（通信・盗聴器の可能性）", detectedFrequency),
            threatLevel: .high
        )]
    }
}
