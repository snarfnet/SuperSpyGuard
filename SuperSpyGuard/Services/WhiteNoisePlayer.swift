import Foundation
import AVFoundation

@MainActor
class WhiteNoisePlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var volume: Float = 0.5
    @Published var noiseType: NoiseType = .white

    enum NoiseType: String, CaseIterable {
        case white  = "ホワイトノイズ"
        case pink   = "ピンクノイズ"
        case brown  = "ブラウンノイズ"
    }

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var pinkState: Float = 0
    private var brownState: Float = 0

    func toggle() {
        if isPlaying { stop() } else { play() }
    }

    func play() {
        stop()
        let engine = AVAudioEngine()
        audioEngine = engine
        let sampleRate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        let type = noiseType
        var pink: [Float] = Array(repeating: 0, count: 7)
        var brown: Float = 0

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let vol = self.volume
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                let sample: Float
                switch type {
                case .white:
                    sample = white
                case .pink:
                    // Paul Kellet's pink noise algorithm
                    pink[0] = 0.99886 * pink[0] + white * 0.0555179
                    pink[1] = 0.99332 * pink[1] + white * 0.0750759
                    pink[2] = 0.96900 * pink[2] + white * 0.1538520
                    pink[3] = 0.86650 * pink[3] + white * 0.3104856
                    pink[4] = 0.55000 * pink[4] + white * 0.5329522
                    pink[5] = -0.7616 * pink[5] - white * 0.0168980
                    let sum = pink[0]+pink[1]+pink[2]+pink[3]+pink[4]+pink[5] + white * 0.5362
                    pink[6] = white * 0.115926
                    sample = sum * 0.11
                case .brown:
                    brown = (brown + 0.02 * white) / 1.02
                    sample = brown * 3.5
                }
                let out = sample * vol * 0.7
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = out
                }
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isPlaying = true
        } catch {
            print("WhiteNoisePlayer error: \(error)")
        }
    }

    func stop() {
        audioEngine?.stop()
        if let node = sourceNode { audioEngine?.detach(node) }
        sourceNode = nil
        audioEngine = nil
        isPlaying = false
    }

    func updateVolume(_ v: Float) {
        volume = v
        audioEngine?.mainMixerNode.outputVolume = v
    }
}
