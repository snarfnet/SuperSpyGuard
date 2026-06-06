import Foundation
@preconcurrency import AVFoundation

@MainActor
class LightScanner: ObservableObject {
    @Published var brightSpotCount: Int = 0
    @Published var isAnomalyDetected = false

    private var captureSession: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var frameCount = 0

    func start() {
        brightSpotCount = 0
        isAnomalyDetected = false
        frameCount = 0
        setupCamera()
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        output = nil
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        // Set minimal exposure to make IR LEDs stand out
        try? device.lockForConfiguration()
        if device.isExposureModeSupported(.custom) {
            device.setExposureModeCustom(duration: CMTime(value: 1, timescale: 1000),
                                          iso: device.activeFormat.minISO) { _ in }
        }
        device.unlockForConfiguration()

        let out = AVCaptureVideoDataOutput()
        output = out
        out.setSampleBufferDelegate(VideoDelegate { [weak self] count in
            Task { @MainActor in
                guard let self else { return }
                self.brightSpotCount = count
                self.frameCount += 1
                if count > 3 && self.frameCount > 10 {
                    self.isAnomalyDetected = true
                }
            }
        }, queue: DispatchQueue(label: "light.scanner"))

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(out) { session.addOutput(out) }

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func getResults() -> [DetectedItem] {
        guard isAnomalyDetected else { return [] }
        return [DetectedItem(
            phase: .light,
            name: "不審な光源を検出",
            detail: "赤外線LEDの可能性がある輝点を\(brightSpotCount)箇所検出",
            threatLevel: brightSpotCount > 5 ? .high : .medium
        )]
    }
}

private class VideoDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let onDetect: (Int) -> Void
    init(_ onDetect: @escaping (Int) -> Void) { self.onDetect = onDetect }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = base.assumingMemoryBound(to: UInt8.self)

        var spotCount = 0
        let step = 8
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * 4
                let r = Int(buffer[offset + 2])
                let g = Int(buffer[offset + 1])
                let b = Int(buffer[offset])
                // Bright white/near-white spots (potential IR LED glow)
                if r > 230 && g > 230 && b > 230 { spotCount += 1 }
            }
        }

        onDetect(spotCount / 4)
    }
}
