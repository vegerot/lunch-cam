import AVFoundation
import AVKit
import Photos
import SwiftUI

@main
struct LunchCamApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
        }
    }
}

/// One camera in 3:4 with the other inset in the top-left corner: the rear camera is the
/// full frame until a tap on the inset swaps them. The front camera is always mirrored.
/// A shutter (on screen, or a volume button) saves the photo and opens the share sheet.
struct CameraView: View {
    private let camera = Camera()
    @State private var shot: Shot?
    @State private var swapped = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            Preview(layer: swapped ? camera.frontPreview : camera.rearPreview)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    GeometryReader { photo in
                        let width = photo.size.width
                        Preview(layer: swapped ? camera.rearPreview : camera.frontPreview)
                            .frame(width: width * Inset.size, height: photo.size.height * Inset.size)
                            .clipShape(RoundedRectangle(cornerRadius: width * Inset.cornerRadius))
                            .onTapGesture {
                                swapped.toggle()
                                print("swapped: \(swapped)")
                            }
                            .accessibilityLabel("Swap cameras")
                            .padding(width * Inset.margin)
                    }
                }
                .frame(maxHeight: .infinity)
            Button(action: { shoot(via: "screen button") }) {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 2).padding(4))
            }
            .accessibilityLabel("Shutter")
            .padding(.bottom, 24)
        }
        .task { await camera.start() }
        // The volume buttons (and other hardware capture buttons) fire the shutter on release.
        .onCameraCaptureEvent { event in
            if event.phase == .ended { shoot(via: "hardware button") }
        }
        .sheet(item: $shot) { shot in
            ShareSheet(image: shot.image).onAppear { print("share sheet shown") }
        }
    }

    private func shoot(via source: String) {
        guard let image = camera.photo(swapped: swapped) else { return }
        // iOS asks for add-only Photos access the first time.
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { saved, error in
            print("saved to Photos: \(saved) \(error?.localizedDescription ?? "")")
        }
        // A copy the Mac can fetch over the cable to look at the result.
        let copy = URL.documentsDirectory.appending(path: "last.jpg")
        try? image.jpegData(compressionQuality: 0.9)?.write(to: copy)
        print("shot via \(source), swapped \(swapped): \(Int(image.size.width))x\(Int(image.size.height))")
        shot = Shot(image: image)
    }
}

struct Shot: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Hosts a camera preview layer and keeps it the size of the view.
struct Preview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> LayerHost { LayerHost(hosted: layer) }
    func updateUIView(_ view: LayerHost, context: Context) { view.hosted = layer }

    final class LayerHost: UIView {
        // Adding a layer here also takes it out of the view that showed it before the swap.
        var hosted: CALayer {
            didSet {
                layer.addSublayer(hosted)
                setNeedsLayout()
            }
        }

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
