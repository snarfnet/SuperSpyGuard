import Foundation
import AVFoundation
import Accelerate

@MainActor
class BugTransmissionTester: ObservableObject {
    @Published var isRunning = false
    @Published var currentPhase: TestPhase = .idle
    @Published var progress: Double = 0
    @Published var results: [TestResult] = []
    @Published var overallVerdict: Verdict = .safe
    @Published var statusText = "テスト準備完了"

    enum TestPhase: String {
        case idle       = "待機中"
        case baseline   = "環境音ベースライン取得中"
        case tone1      = "1kHzテストトーン送信中"
        case tone2      = "3kHzテストトーン送信中"
        case tone3      = "7kHzテストトーン送信中"
        case sweep      = "スイープ信号送信中"
        case analysis   = "分析中"
        case done       = "完了"
    }

    enum Verdict: String {
        case safe       = "安全"
        case suspicious = "要注意"
        case danger     = "危険"
    }

    struct TestResult: Identifiable {
        let id = UUID()
        let testName: String
        let frequency: String
        let feedbackLevel: Double   // 0-1
        let anomalyDetected: Bool
        let detail: String
    }

    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var testTask: Task<Void, Never>?
    private var capturedMagnitudes: [Float] = []
    private var baselineMagnitudes: [Float] = []
    private let fftSize = 4096

    func start() {
        guard !isRunning else { return }
        isRunning = true
        results = []
        overallVerdict = .safe
        progress = 0

        testTask = Task {
            await runTestSequence()
        }
    }

    func stop() {
        testTask?.cancel()
        testTask = nil
        stopAudio()
        isRunning = false
        currentPhase = .idle
        statusText = "テスト中断"
    }

    private func runTestSequence() async {
        // Phase 1: Baseline
        currentPhase = .baseline
        statusText = "環境音を計測しています... 静かにしてください"
        progress = 0.05
        await captureAudio(duration: 3.0)
        baselineMagnitudes = capturedMagnitudes
        progress = 0.15

        if Task.isCancelled { return }

        // Phase 2-4: Test tones
        let tones: [(phase: TestPhase, freq: Double, name: String)] = [
            (.tone1, 1000, "1kHz 基本トーン"),
            (.tone2, 3000, "3kHz 中域トーン"),
            (.tone3, 7000, "7kHz 高域トーン"),
        ]

        for (idx, tone) in tones.enumerated() {
            if Task.isCancelled { return }
            currentPhase = tone.phase
            statusText = "\(tone.name)を再生・分析中..."
            progress = 0.15 + Double(idx) * 0.2

            let result = await runToneTest(frequency: tone.freq, name: tone.name, duration: 3.0)
            results.append(result)
            progress = 0.15 + Double(idx + 1) * 0.2
        }

        if Task.isCancelled { return }

        // Phase 5: Sweep
        currentPhase = .sweep
        statusText = "周波数スイープ信号を分析中..."
        progress = 0.8
        let sweepResult = await runSweepTest(duration: 3.0)
        results.append(sweepResult)
        progress = 0.9

        // Phase 6: Analysis
        currentPhase = .analysis
        statusText = "結果を分析中..."
        try? await Task.sleep(nanoseconds: 500_000_000)

        let anomalyCount = results.filter(\.anomalyDetected).count
        if anomalyCount >= 3 {
            overallVerdict = .danger
        } else if anomalyCount >= 1 {
            overallVerdict = .suspicious
        } else {
            overallVerdict = .safe
        }

        progress = 1.0
        currentPhase = .done
        statusText = "テスト完了"
        stopAudio()
        isRunning = false
    }

    private func runToneTest(frequency: Double, name: String, duration: Double) async -> TestResult {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement,
                                                            options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return TestResult(testName: name, frequency: "\(Int(frequency))Hz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "オーディオ設定エラー")
        }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        // Generate tone buffer
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return TestResult(testName: name, frequency: "\(Int(frequency))Hz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "バッファ作成エラー")
        }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            data[i] = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate)) * 0.3
        }

        // Capture mic while playing
        var captured: [[Float]] = []
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: inputFormat) { buf, _ in
            guard let ch = buf.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(buf.frameLength)))
            captured.append(samples)
        }

        do {
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(buffer, at: nil)
        } catch {
            return TestResult(testName: name, frequency: "\(Int(frequency))Hz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "再生エラー")
        }

        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 500_000_000)

        input.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()

        // Analyze captured audio for feedback
        let feedbackLevel = analyzeFeedback(captured: captured, toneFreq: frequency, sampleRate: inputFormat.sampleRate)
        let anomaly = feedbackLevel > 0.35
        let detail: String
        if anomaly {
            detail = "テストトーンに対する異常な反響パターンを検出。盗聴器がトーンを拾い再発信している可能性"
        } else {
            detail = "正常な反響レベル。盗聴器による再発信の兆候なし"
        }

        return TestResult(testName: name, frequency: "\(Int(frequency))Hz",
                        feedbackLevel: feedbackLevel, anomalyDetected: anomaly, detail: detail)
    }

    private func runSweepTest(duration: Double) async -> TestResult {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement,
                                                            options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return TestResult(testName: "周波数スイープ", frequency: "100-15kHz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "オーディオ設定エラー")
        }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return TestResult(testName: "周波数スイープ", frequency: "100-15kHz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "バッファ作成エラー")
        }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        let startFreq = 100.0
        let endFreq = 15000.0
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let freq = startFreq + (endFreq - startFreq) * (t / duration)
            data[i] = Float(sin(2.0 * .pi * freq * t)) * 0.25
        }

        var captured: [[Float]] = []
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: inputFormat) { buf, _ in
            guard let ch = buf.floatChannelData?[0] else { return }
            captured.append(Array(UnsafeBufferPointer(start: ch, count: Int(buf.frameLength))))
        }

        do {
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(buffer, at: nil)
        } catch {
            return TestResult(testName: "周波数スイープ", frequency: "100-15kHz",
                            feedbackLevel: 0, anomalyDetected: false, detail: "再生エラー")
        }

        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 500_000_000)

        input.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()

        let feedbackLevel = analyzeSweepFeedback(captured: captured, sampleRate: inputFormat.sampleRate)
        let anomaly = feedbackLevel > 0.3
        let detail = anomaly
            ? "スイープ信号に対して特定周波数で異常な共振を検出。電子機器の存在が疑われます"
            : "スイープ範囲全域で正常な応答。電子機器由来の共振なし"

        return TestResult(testName: "周波数スイープ", frequency: "100-15kHz",
                        feedbackLevel: feedbackLevel, anomalyDetected: anomaly, detail: detail)
    }

    private func analyzeFeedback(captured: [[Float]], toneFreq: Double, sampleRate: Double) -> Double {
        guard !captured.isEmpty else { return 0 }

        // Flatten and take last portion (after speaker stabilizes)
        let allSamples = captured.flatMap { $0 }
        let analysisStart = allSamples.count / 3
        guard analysisStart < allSamples.count else { return 0 }
        let samples = Array(allSamples[analysisStart...])
        guard samples.count >= fftSize else { return 0 }

        // FFT on captured audio
        let mags = performSimpleFFT(samples, count: fftSize, sampleRate: sampleRate)
        let binHz = sampleRate / Double(fftSize)

        // Check for energy at harmonics of the test tone (feedback signature)
        var harmonicEnergy: Double = 0
        var totalEnergy: Double = 0

        for i in 0..<mags.count {
            totalEnergy += Double(mags[i])
            let freq = Double(i) * binHz
            // Check 2nd through 5th harmonics
            for h in 2...5 {
                let harmonicFreq = toneFreq * Double(h)
                if abs(freq - harmonicFreq) < binHz * 2 {
                    harmonicEnergy += Double(mags[i])
                }
            }
        }

        guard totalEnergy > 0 else { return 0 }
        return min(1.0, harmonicEnergy / totalEnergy * 20)
    }

    private func analyzeSweepFeedback(captured: [[Float]], sampleRate: Double) -> Double {
        guard !captured.isEmpty else { return 0 }
        let allSamples = captured.flatMap { $0 }
        guard allSamples.count >= fftSize else { return 0 }

        let mags = performSimpleFFT(Array(allSamples.suffix(fftSize)), count: fftSize, sampleRate: sampleRate)

        // Look for sharp spikes (resonance points)
        var spikeCount = 0
        let avg = mags.reduce(0, +) / Float(mags.count)
        for mag in mags {
            if mag > avg * 8 { spikeCount += 1 }
        }

        return min(1.0, Double(spikeCount) / 20.0)
    }

    private func performSimpleFFT(_ samples: [Float], count: Int, sampleRate: Double) -> [Float] {
        let log2n = vDSP_Length(log2(Float(count)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2)) else { return [] }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfCount = count / 2
        var real = [Float](repeating: 0, count: halfCount)
        var imag = [Float](repeating: 0, count: halfCount)
        var input = Array(samples.prefix(count))

        input.withUnsafeMutableBufferPointer { inputPtr in
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

        var mags = [Float](repeating: 0, count: halfCount)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfCount))
            }
        }

        return mags
    }

    private func captureAudio(duration: Double) async {
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        var allSamples: [Float] = []

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { buf, _ in
            guard let ch = buf.floatChannelData?[0] else { return }
            allSamples.append(contentsOf: UnsafeBufferPointer(start: ch, count: Int(buf.frameLength)))
        }

        do { try engine.start() } catch { return }

        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        input.removeTap(onBus: 0)
        engine.stop()

        if allSamples.count >= fftSize {
            capturedMagnitudes = performSimpleFFT(allSamples, count: fftSize, sampleRate: format.sampleRate)
        }
    }

    private func stopAudio() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
