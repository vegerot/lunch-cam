import AVFoundation
import UIKit

/// Where the selfie inset sits, as fractions of the photo width.
/// The preview and the saved photo both use these, so they match.
enum Inset {
    static let size = 0.25
    static let margin = 0.03
    static let cornerRadius = 0.03
}

/// Runs the rear wide camera and the front camera together.
/// Each camera feeds a preview layer, and a data output that keeps its latest frame for the shutter.
final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let rearPreview = AVCaptureVideoPreviewLayer()
    let frontPreview = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureMultiCamSession()
    private let queue = DispatchQueue(label: "camera")
    private let rearFrames = AVCaptureVideoDataOutput()
    private let frontFrames = AVCaptureVideoDataOutput()
    // Only touched on `queue`.
    private var latestRear: CVPixelBuffer?
    private var latestFront: CVPixelBuffer?

    override init() {
        super.init()
        for preview in [rearPreview, frontPreview] {
            preview.setSessionWithNoConnection(session)
            preview.videoGravity = .resizeAspectFill
        }
    }

    func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            print("camera access denied")
            return
        }
        for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { note in
                print("session problem: \(name.rawValue) \(note.userInfo ?? [:])")
            }
        }
        queue.async { [self] in
            session.beginConfiguration()
            connect(.back, preview: rearPreview, frames: rearFrames)
            connect(.front, preview: frontPreview, frames: frontFrames)
            session.commitConfiguration()
            session.startRunning()
            // A cost above 1 means the phone cannot run this combination of formats.
            print("running: \(session.isRunning), hardwareCost: \(session.hardwareCost)")
        }
    }

    /// The two latest frames as one image: one camera full-frame, the other inset top-left.
    /// The rear camera is the full frame unless `swapped`.
    func photo(swapped: Bool) -> UIImage? {
        let (rear, front) = queue.sync { (latestRear, latestFront) }
        guard let rear, let front else { return nil }

        let context = CIContext()
        func image(_ buffer: CVPixelBuffer) -> UIImage {
            let frame = CIImage(cvPixelBuffer: buffer)
            // Force unwrap: rendering a camera frame only fails when memory runs out.
            return UIImage(cgImage: context.createCGImage(frame, from: frame.extent)!)
        }
        let fullImage = image(swapped ? front : rear)
        let insetImage = image(swapped ? rear : front)

        let size = fullImage.size
        let insetFrame = CGRect(
            x: size.width * Inset.margin,
            y: size.width * Inset.margin,
            width: size.width * Inset.size,
            height: size.height * Inset.size
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // one image pixel per camera pixel
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            fullImage.draw(at: .zero)
            UIBezierPath(roundedRect: insetFrame, cornerRadius: size.width * Inset.cornerRadius).addClip()
            insetImage.draw(in: insetFrame)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let frame = CMSampleBufferGetImageBuffer(sampleBuffer)
        if output === rearFrames { latestRear = frame } else { latestFront = frame }
    }

    private func connect(
        _ position: AVCaptureDevice.Position,
        preview: AVCaptureVideoPreviewLayer,
        frames: AVCaptureVideoDataOutput
    ) {
        // Force unwraps and `try!` below: layer 1 measured that this phone has both cameras,
        // allows them together, and offers 1920x1440 on each.
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)!
        let format = device.formats.first { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return format.isMultiCamSupported && size.width == 1920 && size.height == 1440
        }!
        try! device.lockForConfiguration()
        device.activeFormat = format
        device.unlockForConfiguration()

        let input = try! AVCaptureDeviceInput(device: device)
        session.addInputWithNoConnections(input)
        let port = input.ports(
            for: .video,
            sourceDeviceType: device.deviceType,
            sourceDevicePosition: position
        ).first!

        frames.setSampleBufferDelegate(self, queue: queue)
        session.addOutputWithNoConnections(frames)

        // Ask for the upright angle instead of assuming 90: on this phone the front sensor
        // is mounted differently from the rear one (a fixed 90 showed the selfie upside down).
        let upright = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
            .videoRotationAngleForHorizonLevelPreview
        print("\(position == .front ? "front" : "rear") upright angle: \(upright)")

        for connection in [
            AVCaptureConnection(inputPort: port, videoPreviewLayer: preview),
            AVCaptureConnection(inputPorts: [port], output: frames),
        ] {
            session.addConnection(connection)
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
            connection.videoRotationAngle = upright
        }
    }
}
