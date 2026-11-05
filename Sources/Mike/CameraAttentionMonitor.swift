@preconcurrency import AVFoundation
import Combine
import ImageIO
import Vision

@MainActor
final class CameraAttentionMonitor: ObservableObject {
    @Published private(set) var authorizationText = "Not enabled"
    @Published private(set) var isRunning = false

    private let detector = VisionAttentionDetector()
    private weak var timerController: TimerController?

    func start(for controller: TimerController) {
        timerController = controller
        Task {
            let granted = await requestCameraAccess()
            guard granted else {
                authorizationText = "Camera permission denied"
                controller.updateAttention(.unavailable, phoneHeld: false)
                return
            }

            detector.onResult = { [weak self, weak controller] state, held in
                Task { @MainActor in
                    self?.authorizationText = "On-device analysis active"
                    controller?.updateAttention(state, phoneHeld: held)
                }
            }
            do {
                try detector.start()
                isRunning = true
                authorizationText = "On-device analysis active"
            } catch {
                authorizationText = error.localizedDescription
                controller.updateAttention(.unavailable, phoneHeld: false)
            }
        }
    }

    func stop() {
        detector.stop()
        isRunning = false
        authorizationText = "Camera off"
        timerController?.updateAttention(.unavailable, phoneHeld: false)
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }
}

private final class VisionAttentionDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onResult: (@Sendable (AttentionState, Bool) -> Void)?

    private let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "Mike.camera.capture", qos: .userInitiated)
    private let stateLock = NSLock()
    private var isAnalyzing = false
    private var lastAnalysis = Date.distantPast
    private var possibleDistractionSince: Date?

    func start() throws {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.configuration
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.configuration
        }
        session.addOutput(output)
        session.commitConfiguration()
        captureQueue.async { [session] in session.startRunning() }
    }

    func stop() {
        captureQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        stateLock.withLock {
            possibleDistractionSince = nil
            isAnalyzing = false
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let shouldAnalyze = stateLock.withLock { () -> Bool in
            guard !isAnalyzing, Date().timeIntervalSince(lastAnalysis) >= 0.35 else { return false }
            isAnalyzing = true
            lastAnalysis = Date()
            return true
        }
        guard shouldAnalyze, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        analyze(pixelBuffer)
    }

    private func analyze(_ pixelBuffer: CVPixelBuffer) {
        defer { stateLock.withLock { isAnalyzing = false } }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        do {
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .leftMirrored,
                options: [:]
            )
            try handler.perform([faceRequest, handRequest])

            guard let face = faceRequest.results?.first else {
                clearDistractionAndReport(.unavailable)
                return
            }

            let handNearFace = handRequest.results?.contains(where: { hand in
                guard let points = try? hand.recognizedPoints(.all) else { return false }
                let visible = points.values.filter { $0.confidence > 0.25 }
                guard !visible.isEmpty else { return false }
                let handCenter = visible.reduce(CGPoint.zero) { partial, point in
                    CGPoint(x: partial.x + point.location.x, y: partial.y + point.location.y)
                }.applying(CGAffineTransform(scaleX: 1 / CGFloat(visible.count), y: 1 / CGFloat(visible.count)))
                let expandedFace = face.boundingBox.insetBy(
                    dx: -face.boundingBox.width * 0.9,
                    dy: -face.boundingBox.height * 0.55
                )
                return expandedFace.contains(handCenter)
            }) ?? false

            let yaw = abs(face.yaw?.doubleValue ?? 0)
            let pitch = face.pitch?.doubleValue ?? 0
            let state: AttentionState
            if handNearFace {
                state = .distracted
            } else if pitch < -0.16 {
                state = .reading
            } else if yaw < 0.42 {
                state = .focused
            } else {
                state = .reading
            }

            let now = Date()
            let held: Bool = stateLock.withLock {
                if handNearFace {
                    if possibleDistractionSince == nil { possibleDistractionSince = now }
                    return now.timeIntervalSince(possibleDistractionSince ?? now) >= 3
                } else {
                    possibleDistractionSince = nil
                    return false
                }
            }
            onResult?(state, held)
        } catch {
            clearDistractionAndReport(.unavailable)
        }
    }

    private func clearDistractionAndReport(_ state: AttentionState) {
        stateLock.withLock { possibleDistractionSince = nil }
        onResult?(state, false)
    }

    private enum CameraError: LocalizedError {
        case noCamera
        case configuration

        var errorDescription: String? {
            switch self {
            case .noCamera: "No camera was found"
            case .configuration: "The camera could not be configured"
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
