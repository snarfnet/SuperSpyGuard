import Foundation
import AVFoundation
import CoreImage
import Vision

@MainActor
class LensDetector: ObservableObject {
    @Published var detectedLensCount: Int = 0
    @Published var isAnomalyDetected = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    private var captureSession: AVCaptureSession?
    private var frameCount = 0
    private var suspectFrames = 0

    func start() {
        detectedLensCount = 0
        isAnomalyDetected = false
        frameCount = 0
        suspectFrames = 0
        setupCamera()
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        previewLayer = preview

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(
            LensFrameDelegate { [weak self] count in
                Task { @MainActor in
                    guard let self else { return }
                    self.frameCount += 1
                    if count > 0 { self.suspectFrames += 1 }
                    // Confirmed after 15+ frames with consistent detections
                    if self.frameCount >= 15 && self.suspectFrames >= 8 {
                        self.detectedLensCount = count
                        self.isAnomalyDetected = true
                    }
                }
            },
            queue: DispatchQueue(label: "lens.detector")
        )
        if session.canAddOutput(output) { session.addOutput(output) }

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func getResults() -> [DetectedItem] {
        guard isAnomalyDetected else { return [] }
        return [DetectedItem(
            phase: .lens,
            name: "カメラレンズの疑いあり",
            detail: "AIが\(detectedLensCount)箇所の円形反射パターンを検出。隠しカメラの可能性があります。",
            threatLevel: detectedLensCount > 2 ? .high : .medium
        )]
    }
}

private class LensFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let onDetect: (Int) -> Void
    init(_ onDetect: @escaping (Int) -> Void) { self.onDetect = onDetect }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Use Vision contour detection to find circular shapes
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = false

        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .right)
        try? handler.perform([request])

        guard let contours = request.results?.first?.topLevelContours else {
            onDetect(0); return
        }

        var lensCount = 0
        for contour in contours {
            let path = contour.normalizedPath
            let bb = path.boundingBoxOfPath
            let aspect = bb.width / max(bb.height, 0.001)
            let pointCount = contour.pointCount
            let area = bb.width * bb.height

            // Lens: near-circular contour, small-medium size, sufficient detail
            let isCircular = aspect > 0.7 && aspect < 1.4
            let isSmall = area > 0.001 && area < 0.04
            let hasSufficientDetail = pointCount > 20

            if isCircular && isSmall && hasSufficientDetail {
                lensCount += 1
            }
        }

        onDetect(min(lensCount, 5))
    }
}
