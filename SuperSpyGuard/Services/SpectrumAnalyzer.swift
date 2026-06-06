import Foundation
@preconcurrency import AVFoundation
import Accelerate

@MainActor
class SpectrumAnalyzer: ObservableObject {
    @Published var isRunning = false
    @Published var magnitudes: [Float] = []
    @Published var waterfallRows: [[Float]] = []
    @Published var peakFrequency: Double = 0
    @Published var peakMagnitude: Float = 0
    @Published var suspiciousBands: [SuspiciousBand] = []

    struct SuspiciousBand: Identifiable {
        let id = UUID()
        let label: String
        let freqRange: String
        let level: Float
    }

    private var audioEngine: AVAudioEngine?
    private var sampleRate: Double = 44100
    private let fftSize = 4096
    private let maxWaterfallRows = 80

    // Frequency bands of interest (audio-range artifacts from electronic devices)
    private let bands: [(label: String, lo: Double, hi: Double, desc: String)] = [
        ("電源ハム",      45,    65,    "50/60Hz電源ノイズ"),
        ("低周波異常",     200,   800,   "変調器の音声帯域"),
        ("中周波キャリア",  1000,  4000,  "音声送信のサブキャリア"),
        ("高周波ノイズ",   6000,  10000, "電子回路の発振音"),
        ("超音波域",      15000, 22000, "超音波発信・盗聴器漏れ"),
    ]

    func start() {
        guard !isRunning else { return }
        isRunning = true
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        waterfallRows = []
        suspiciousBands = []
        peakFrequency = 0
        peakMagnitude = 0
        setupAudio()
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    private func setupAudio() {
        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount >= self.fftSize else { return }

            let mags = self.performFFT(channelData, count: self.fftSize)

            Task { @MainActor in
                self.magnitudes = mags
                self.updateWaterfall(mags)
                self.analyzePeaks(mags)
            }
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            isRunning = false
        }
    }

    private func performFFT(_ data: UnsafePointer<Float>, count: Int) -> [Float] {
        let log2n = vDSP_Length(log2(Float(count)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfCount = count / 2
        var real = [Float](repeating: 0, count: halfCount)
        var imag = [Float](repeating: 0, count: halfCount)

        // Pack into split complex
        var inputData = Array(UnsafeBufferPointer(start: data, count: count))
        inputData.withUnsafeMutableBufferPointer { inputPtr in
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfCount) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfCount))
                    }
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }
        }

        // Compute magnitudes
        var mags = [Float](repeating: 0, count: halfCount)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfCount))
            }
        }

        // Convert to dB scale
        var dbMags = [Float](repeating: 0, count: halfCount)
        var one: Float = 1.0
        vDSP_vdbcon(mags, 1, &one, &dbMags, 1, vDSP_Length(halfCount), 0)

        // Normalize to 0-1 range (clamp -80dB to +20dB)
        for i in 0..<halfCount {
            dbMags[i] = max(0, min(1, (dbMags[i] + 80) / 100))
        }

        return dbMags
    }

    private func updateWaterfall(_ mags: [Float]) {
        // Downsample to 128 bins for waterfall
        let targetBins = 128
        let step = max(1, mags.count / targetBins)
        var row = [Float](repeating: 0, count: targetBins)
        for i in 0..<targetBins {
            let start = i * step
            let end = min(start + step, mags.count)
            if start < end {
                row[i] = mags[start..<end].max() ?? 0
            }
        }

        waterfallRows.append(row)
        if waterfallRows.count > maxWaterfallRows {
            waterfallRows.removeFirst()
        }
    }

    private func analyzePeaks(_ mags: [Float]) {
        let binHz = sampleRate / Double(fftSize)

        // Find global peak
        if let maxIdx = mags.indices.max(by: { mags[$0] < mags[$1] }) {
            peakFrequency = Double(maxIdx) * binHz
            peakMagnitude = mags[maxIdx]
        }

        // Analyze each suspicious band
        var detected: [SuspiciousBand] = []
        for band in bands {
            let loBin = Int(band.lo / binHz)
            let hiBin = min(mags.count - 1, Int(band.hi / binHz))
            guard loBin < hiBin, loBin < mags.count else { continue }

            let slice = mags[loBin...hiBin]
            let maxLevel = slice.max() ?? 0

            if maxLevel > 0.45 {
                detected.append(SuspiciousBand(
                    label: band.label,
                    freqRange: "\(Int(band.lo))-\(Int(band.hi))Hz",
                    level: maxLevel
                ))
            }
        }

        suspiciousBands = detected
    }

    func frequencyForBin(_ bin: Int, totalBins: Int) -> Double {
        let maxFreq = sampleRate / 2
        return maxFreq * Double(bin) / Double(totalBins)
    }
}
