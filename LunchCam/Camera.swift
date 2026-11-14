import AVFoundation

/// Runs the rear wide camera and the front camera together and feeds one preview layer each.
final class Camera {
    let rearPreview = AVCaptureVideoPreviewLayer()
    let frontPreview = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureMultiCamSession()
    private let queue = DispatchQueue(label: "camera")

    init() {
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
        queue.async { [self] in
            session.beginConfiguration()
            connect(.back, to: rearPreview)
            connect(.front, to: frontPreview)
            session.commitConfiguration()
            session.startRunning()
            // A cost above 1 means the phone cannot run this combination of formats.
            print("running: \(session.isRunning), hardwareCost: \(session.hardwareCost)")
        }
    }

    private func connect(_ position: AVCaptureDevice.Position, to preview: AVCaptureVideoPreviewLayer) {
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

        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: preview)
        session.addConnection(connection)
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = position == .front
        // Ask for the upright angle instead of assuming 90: on this phone the front sensor
        // is mounted differently from the rear one (a fixed 90 showed the selfie upside down).
        let upright = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
            .videoRotationAngleForHorizonLevelPreview
        connection.videoRotationAngle = upright
        print("\(position == .front ? "front" : "rear") upright angle: \(upright)")
    }
}
