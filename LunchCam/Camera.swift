import AVFoundation
import UIKit
import UniformTypeIdentifiers

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
    private var latestRear: CMSampleBuffer?
    private var latestFront: CMSampleBuffer?

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

    /// The two latest frames as one HEIC file: one camera full-frame, the other at `inset`.
    /// The rear camera is the full frame unless `swapped`. The file carries the full-frame
    /// camera's own details (time, exposure, lens) and `place`, if given.
    func photo(swapped: Bool, inset: Inset, place: [String: Any]?) -> (image: UIImage, file: Data)? {
        let (rear, front) = queue.sync { (latestRear, latestFront) }
        guard let rear, let front else { return nil }

        let context = CIContext()
        func image(_ sample: CMSampleBuffer, front: Bool) -> UIImage {
            // Force unwrap: a camera frame always holds a picture.
            let frame = upright(CMSampleBufferGetImageBuffer(sample)!, front: front)
            // Force unwrap: rendering a camera frame only fails when memory runs out.
            return UIImage(cgImage: context.createCGImage(frame, from: frame.extent)!)
        }
        let fullImage = image(swapped ? front : rear, front: swapped)
        let insetImage = image(swapped ? rear : front, front: !swapped)

        let size = fullImage.size
        let insetFrame = inset.frame(in: size)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // one image pixel per camera pixel
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            fullImage.draw(at: .zero)
            UIBezierPath(roundedRect: insetFrame, cornerRadius: size.width * Inset.cornerRadius).addClip()
            insetImage.draw(in: insetFrame)
        }

        // Every frame carries the camera's record of how it was taken (measured on the phone).
        let exif = CMGetAttachment(swapped ? front : rear, key: kCGImagePropertyExifDictionary, attachmentModeOut: nil)
        var properties = Metadata.properties(
            exif: exif as? [String: Any] ?? [:], width: Int(size.width), height: Int(size.height), place: place
        )
        properties[kCGImageDestinationLossyCompressionQuality as String] = 0.9
        // Force unwraps: the phone can write HEIC, and the image was drawn just above.
        let file = NSMutableData()
        let destination = CGImageDestinationCreateWithData(file, UTType.heic.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image.cgImage!, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return (image, file as Data)
    }

    /// A saved frame turned upright, the same way its preview is turned.
    private func upright(_ buffer: CVPixelBuffer, front: Bool) -> CIImage {
        let asked = Int(connected[front ? 1 : 0].videoRotationAngleForHorizonLevelPreview)
        // The selfie frames are mirrored, and in a mirror a turn runs the other way. Measured on
        // the phone: the camera's own quarter turn equals `.right` for the rear camera and
        // `.left` for the front camera.
        let clockwise = front ? (360 - asked) % 360 : asked
        // Force unwrap: the phone only asks for quarter turns (every angle seen was one).
        let turn: CGImagePropertyOrientation = [0: .up, 90: .right, 180: .down, 270: .left][clockwise]!
        return CIImage(cvPixelBuffer: buffer).oriented(turn)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let frame = CMSampleBufferGetImageBuffer(sampleBuffer)
        if output === rearFrames { latestRear = sampleBuffer } else { latestFront = sampleBuffer }

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
        // The saved frames stay at angle 0, as the sensor delivers them; `photo` turns them.
        // Set explicitly: a new connection of the front camera starts at 180 (measured).
        connections[1].videoRotationAngle = 0

        // Ask for the upright angle instead of assuming 90: on this phone the front sensor
        // is mounted differently from the rear one (a fixed 90 showed the selfie upside down).
        // The angle changes when the phone turns, and when it opens or closes, so keep asking.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
        func turn(to upright: CGFloat) {
            print("\(position == .front ? "front" : "rear") upright angle: \(upright)")
            // Only the preview is turned here. The saved frames stay as the sensor delivers them
            // and are turned in `photo`: turning them in the camera restarts the camera's
            // exposure, which dimmed the selfie for a second after every turn (measured), and
            // takes 0.3 seconds per camera.
            connections[0].videoRotationAngle = upright
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
