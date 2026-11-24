import AVFoundation
import UIKit

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

    /// Called on the main queue when the cameras stop or start delivering real pictures.
    /// They deliver blank ones while Xcode's Device Hub controls the phone.
    var onBlank: (_ blank: Bool) -> Void = { _ in }
    // Only touched on `queue`.
    private var frameCount = 0
    private var blank = false

    /// Called on the main queue when the pictures change shape: true when the phone is held
    /// sideways and the pictures are wide (4:3), false when they are tall (3:4).
    var onTurn: (_ landscape: Bool) -> Void = { _ in }
    // Kept alive so they keep reporting; each belongs to one camera.
    private var coordinators: [AVCaptureDevice.RotationCoordinator] = []
    private var angleObservations: [NSKeyValueObservation] = []

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
            DispatchQueue.main.async { [coordinators] in self.connected = coordinators }
            session.startRunning()
            // A cost above 1 means the phone cannot run this combination of formats.
            print("running: \(session.isRunning), hardwareCost: \(session.hardwareCost)")
        }
    }

    /// For the tint: how far a camera's picture is from upright, in degrees. It is the angle
    /// its preview really has minus the angle the phone asks for, so 0 means upright.
    func tilt(front: Bool) -> Double {
        // The rear camera is connected first. Before both are connected there is no picture.
        guard connected.count == 2 else { return 0 }
        let asked = connected[front ? 1 : 0].videoRotationAngleForHorizonLevelPreview
        let has = (front ? frontPreview : rearPreview).connection?.videoRotationAngle ?? asked
        return has - asked
    }
    /// The coordinators again, for the main thread, set once both cameras are connected.
    /// `tilt` must not wait for `queue`: connecting a preview waits for the main thread in turn.
    private var connected: [AVCaptureDevice.RotationCoordinator] = []

    /// The two latest frames as one image: one camera full-frame, the other at `inset`.
    /// The rear camera is the full frame unless `swapped`.
    func photo(swapped: Bool, inset: Inset) -> UIImage? {
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
        let insetFrame = inset.frame(in: size)
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

        // Once a second, look whether the rear camera is delivering a real picture.
        guard output === rearFrames, let frame else { return }
        frameCount += 1
        guard frameCount % 30 == 0 else { return }
        // Xcode's Device Hub gives apps frames where every pixel is the same black (measured:
        // brightness 16 everywhere). A real sensor has noise even with the lens covered.
        // Force unwrap: the cameras deliver two-plane frames, brightness first (measured).
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        let brightness = CVPixelBufferGetBaseAddressOfPlane(frame, 0)!.assumingMemoryBound(to: UInt8.self)
        // A row can hold more bytes than the picture is wide; the spare ones are not black
        // (measured: 1472 bytes for 1440 pixels), so only real pixels are sampled.
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        let columns = stride(from: 0, to: CVPixelBufferGetWidthOfPlane(frame, 0), by: 41)
        let nowBlank = stride(from: 0, to: CVPixelBufferGetHeightOfPlane(frame, 0), by: 37).allSatisfy { row in
            columns.allSatisfy { brightness[row * rowBytes + $0] == brightness[0] }
        }
        CVPixelBufferUnlockBaseAddress(frame, .readOnly)
        if nowBlank != blank {
            blank = nowBlank
            print("cameras blank: \(nowBlank)")
            DispatchQueue.main.async { self.onBlank(nowBlank) }
        }
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

        let connections = [
            AVCaptureConnection(inputPort: port, videoPreviewLayer: preview),
            AVCaptureConnection(inputPorts: [port], output: frames),
        ]
        for connection in connections {
            session.addConnection(connection)
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }

        // Ask for the upright angle instead of assuming 90: on this phone the front sensor
        // is mounted differently from the rear one (a fixed 90 showed the selfie upside down).
        // The angle changes when the phone turns, and when it opens or closes, so keep asking.
        // The saved frames use the preview's angle, so the photo is what the screen showed.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
        func turn(to upright: CGFloat) {
            print("\(position == .front ? "front" : "rear") upright angle: \(upright)")
            // The preview turns at once: it is only a transform. Turning the saved frames takes
            // about 0.3 seconds per camera (measured), so that happens on the camera queue.
            // On the main thread it froze the app for 0.6 seconds in the middle of every turn.
            connections[0].videoRotationAngle = upright
            queue.async { connections[1].videoRotationAngle = upright }
            // Both cameras turn together, so one of them reporting the shape is enough.
            // The sensors are wide: at 0 or 180 degrees the picture stays wide.
            if position == .back {
                let landscape = upright.truncatingRemainder(dividingBy: 180) == 0
                DispatchQueue.main.async { self.onTurn(landscape) }
            }
        }
        turn(to: coordinator.videoRotationAngleForHorizonLevelPreview)
        // Changes arrive on the main queue. The first value does not arrive, hence the line above.
        angleObservations.append(
            coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { _, change in
                turn(to: change.newValue!) // `.new` always carries the new value
            }
        )
        coordinators.append(coordinator)
    }
}
