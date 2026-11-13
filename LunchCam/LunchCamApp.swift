import AVFoundation
import SwiftUI

@main
struct LunchCamApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
        }
    }
}

/// The rear camera in 3:4 with the mirrored front camera inset in the top-left corner.
struct CameraView: View {
    private let camera = Camera()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Preview(layer: camera.rearPreview)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    GeometryReader { photo in
                        Preview(layer: camera.frontPreview)
                            .frame(width: photo.size.width / 4, height: photo.size.height / 4)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(12)
                    }
                }
        }
        .task { await camera.start() }
    }
}

/// Hosts a camera preview layer and keeps it the size of the view.
struct Preview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> LayerHost { LayerHost(hosted: layer) }
    func updateUIView(_ view: LayerHost, context: Context) {}

    final class LayerHost: UIView {
        private let hosted: CALayer

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
            layer.addSublayer(hosted)
        }

        required init?(coder: NSCoder) { fatalError("not used: the view is created in code") }

        override func layoutSubviews() {
            super.layoutSubviews()
            hosted.frame = bounds
        }
    }
}
