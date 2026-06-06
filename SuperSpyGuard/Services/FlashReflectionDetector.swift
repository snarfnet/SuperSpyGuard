@preconcurrency import AVFoundation
import CoreImage
import Accelerate

@MainActor
class FlashReflectionDetector: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var detectedCount = 0
    @Published var hotspots: [ReflectionHotspot] = []
    @Published var strobeProgress: Double = 0
    @Published var statusText = "準備完了"
    @Published var previewSession: AVCaptureSession?

    private var torchDevice: AVCaptureDevice?
    private var delegate: FlashFrameDelegate?
    private var strobeTask: Task<Void, Never>?

    struct ReflectionHotspot: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let intensity: Double
    }

    private let totalStrobeCycles = 12
    private let strobeOnDuration: UInt64  = 80_000_000   // 80ms
    private let strobeOffDuration: UInt64 = 120_000_000  // 120ms

    func start() {
        guard !isRunning else { return }
        isRunning = true
        detectedCount = 0
        hotspots = []
        strobeProgress = 0
        statusText = "カメラ起動中..."
        setupCamera()
    }

    func stop() {
        strobeTask?.cancel()
        strobeTask = nil
        setTorch(on: false)
        previewSession?.stopRunning()
        previewSession = nil
        delegate = nil
        isRunning = false
        statusText = detectedCount > 0
            ? "\(detectedCount)箇所の反射点を検出"
            : "反射点は検出されませんでした"
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            statusText = "カメラまたはフラッシュが利用できません"
            isRunning = false
            return
        }

        session.addInput(input)
        torchDevice = device

        let frameDelegate = FlashFrameDelegate()
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(frameDelegate, queue: DispatchQueue(label: "flash.reflection"))
        if session.canAddOutput(output) { session.addOutput(output) }

        delegate = frameDelegate
        previewSession = session

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }

        strobeTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await runStrobeSequence()
        }
    }

    private func runStrobeSequence() async {
        statusText = "フラッシュ点滅中... 部屋をゆっくり見回してください"

        for cycle in 0..<totalStrobeCycles {
            if Task.isCancelled { return }

            // Capture OFF frame (baseline)
            delegate?.captureMode = .off
            try? await Task.sleep(nanoseconds: strobeOffDuration)
            let offData = delegate?.lastFrameData

            // Flash ON
            setTorch(on: true)
            delegate?.captureMode = .on
            try? await Task.sleep(nanoseconds: strobeOnDuration)
            let onData = delegate?.lastFrameData

            // Flash OFF
            setTorch(on: false)

            strobeProgress = Double(cycle + 1) / Double(totalStrobeCycles)

            // Analyze difference
            if let off = offData, let on = onData, off.width == on.width, off.height == on.height {
                let spots = analyzeFrameDifference(off: off, on: on)
                if !spots.isEmpty {
                    hotspots.append(contentsOf: spots)
                    detectedCount = hotspots.count
                }
            }
        }

        stop()
    }

    private func setTorch(on: Bool) {
        guard let device = torchDevice else { return }
        try? device.lockForConfiguration()
        if on {
            try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            device.torchMode = .off
        }
        device.unlockForConfiguration()
    }

    private func analyzeFrameDifference(off: FrameData, on: FrameData) -> [ReflectionHotspot] {
        let width = off.width
        let height = off.height
        let bytesPerRow = off.bytesPerRow

        let gridCols = 16
        let gridRows = 12
        let cellW = width / gridCols
        let cellH = height / gridRows
        let threshold: Int = 80

        var spots: [ReflectionHotspot] = []

        for gy in 0..<gridRows {
            for gx in 0..<gridCols {
                var totalDiff: Int = 0
                var sampleCount = 0

                let startY = gy * cellH
                let startX = gx * cellW
                for py in stride(from: startY, to: min(startY + cellH, height), by: 4) {
                    for px in stride(from: startX, to: min(startX + cellW, width), by: 4) {
                        let offset = py * bytesPerRow + px * 4
                        guard offset + 2 < off.bytes.count, offset + 2 < on.bytes.count else { continue }
                        let offLum = Int(off.bytes[offset + 1]) * 2 + Int(off.bytes[offset]) + Int(off.bytes[offset + 2])
                        let onLum = Int(on.bytes[offset + 1]) * 2 + Int(on.bytes[offset]) + Int(on.bytes[offset + 2])
                        let diff = onLum - offLum
                        if diff > 0 { totalDiff += diff }
                        sampleCount += 1
                    }
                }

                guard sampleCount > 0 else { continue }
                let avgDiff = totalDiff / sampleCount

                if avgDiff > threshold {
                    let intensity = min(Double(avgDiff) / 200.0, 1.0)
                    spots.append(ReflectionHotspot(
                        x: (CGFloat(gx) + 0.5) / CGFloat(gridCols),
                        y: (CGFloat(gy) + 0.5) / CGFloat(gridRows),
                        intensity: intensity
                    ))
                }
            }
        }

        return spots
    }
}

// MARK: - Safe Frame Data (copied bytes, no CVPixelBuffer retention)

struct FrameData {
    let bytes: [UInt8]
    let width: Int
    let height: Int
    let bytesPerRow: Int
}

// MARK: - Frame Delegate

private class FlashFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum CaptureMode { case off, on }
    var captureMode: CaptureMode = .off
    var lastFrameData: FrameData?

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let totalBytes = bytesPerRow * height
        let bytes = Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: totalBytes))
        lastFrameData = FrameData(bytes: bytes, width: width, height: height, bytesPerRow: bytesPerRow)
    }
}
