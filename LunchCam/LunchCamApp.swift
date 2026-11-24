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

/// One camera in 3:4 with the other as a small inset: the rear camera is the full frame
/// until a tap on the inset swaps them. A drag moves the inset and a pinch resizes it.
/// The front camera is always mirrored.
/// A shutter (on screen, or a volume button) saves the photo and opens the share sheet.
struct CameraView: View {
    private let camera = Camera()
    @State private var shot: Shot?
    @State private var swapped = false
    @State private var inset = Inset()
    /// The inset as it was when the current drag or pinch began.
    @State private var gestureStart: Inset?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            preview(front: swapped)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    GeometryReader { photo in
                        let frame = inset.frame(in: photo.size)
                        preview(front: !swapped)
                            .frame(width: frame.width, height: frame.height)
                            .clipShape(RoundedRectangle(cornerRadius: photo.size.width * Inset.cornerRadius))
                            .onTapGesture {
                                swapped.toggle()
                                print("swapped: \(swapped)")
                            }
                            // One gesture for both, so a drag and a pinch at the same time
                            // start from the same inset instead of overwriting each other.
                            // The drag is measured on the screen, not inside the inset: the inset
                            // moves under the finger, so its own coordinates undercount the drag.
                            .gesture(
                                DragGesture(coordinateSpace: .global).simultaneously(with: MagnifyGesture())
                                    .onChanged { value in
                                        let start = gestureStart ?? inset
                                        gestureStart = start
                                        let drag = value.first?.translation ?? .zero
                                        inset = start
                                            .scaled(by: Double(value.second?.magnification ?? 1))
                                            .moved(by: CGSize(
                                                width: drag.width / photo.size.width,
                                                height: drag.height / photo.size.height
                                            ))
                                    }
                                    .onEnded { _ in
                                        gestureStart = nil
                                        print("inset: center \(inset.center), size \(inset.size)")
                                    }
                            )
                            .accessibilityLabel("Swap cameras")
                            .position(x: frame.midX, y: frame.midY)
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

    /// One camera's live picture. With the `--tint` launch argument (`./dev install --tint`)
    /// it gets a colored layer and a letter: red F for the front camera, green B for the back.
    /// Device Hub gives apps black camera frames, so without this the two pictures look alike.
    private func preview(front: Bool) -> some View {
        Preview(layer: front ? camera.frontPreview : camera.rearPreview)
            .overlay {
                if ProcessInfo.processInfo.arguments.contains("--tint") {
                    (front ? Color.red : Color.green).opacity(0.4)
                        .overlay {
                            Text(front ? "F" : "B")
                                .font(.system(size: 200, weight: .bold))
                                .minimumScaleFactor(0.1)
                                .foregroundStyle(.white)
                                .padding(8)
                        }
                        .allowsHitTesting(false)
                }
            }
    }

    private func shoot(via source: String) {
        guard let image = camera.photo(swapped: swapped, inset: inset) else { return }
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
                guard hosted !== oldValue else { return }
                layer.addSublayer(hosted)
                swapping = true
                setNeedsLayout()
            }
        }
        /// True from a swap until the next layout, which then animates the layer to its new size.
        private var swapping = false

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
            layer.addSublayer(hosted)
        }

        required init?(coder: NSCoder) { fatalError("not used: the view is created in code") }

        override func layoutSubviews() {
            super.layoutSubviews()
            // Core Animation eases a layer to a new size over a quarter second. That is the swap
            // animation. During a pinch it is turned off, or the picture trails behind the view.
            CATransaction.begin()
            CATransaction.setDisableActions(!swapping)
            hosted.frame = bounds
            CATransaction.commit()
            swapping = false
        }
    }
}
