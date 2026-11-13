import AVFoundation

/// Describes what this phone offers for capturing the rear and front cameras together.
func multiCamReport() -> String {
    var lines = ["multiCamSupported: \(AVCaptureMultiCamSession.isMultiCamSupported)"]

    let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: .unspecified
    )
    let pairAllowed = discovery.supportedMultiCamDeviceSets.contains { set in
        set.contains { $0.position == .back } && set.contains { $0.position == .front }
    }
    lines.append("rear wide + front allowed together: \(pairAllowed)")

    for device in discovery.devices {
        lines.append("")
        lines.append("\(device.position == .back ? "REAR" : "FRONT"): \(device.localizedName)")
        lines.append("  video WxH  maxFps  maxPhoto WxH  (multi-camera formats only)")

        var seen = Set<String>()
        for format in device.formats where format.isMultiCamSupported {
            let video = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let fps = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
            let photo = format.supportedMaxPhotoDimensions
                .max { $0.width * $0.height < $1.width * $1.height }
            let line = "  \(video.width)x\(video.height)  \(Int(fps))  "
                + "\(photo?.width ?? 0)x\(photo?.height ?? 0)"
            // Formats repeat per pixel format; one line per distinct size is enough.
            if seen.insert(line).inserted { lines.append(line) }
        }
    }
    return lines.joined(separator: "\n")
}
