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
    /// True while the phone is held sideways and the cameras deliver wide pictures.
    @State private var landscape = false
    /// True while the cameras deliver blank frames instead of pictures.
    @State private var blank = false
    /// Where the front camera sits on the screen, once the system has said so.
    @State private var lens: CGRect?
    /// The band on the screen where the phone bends, while it is half-folded.
    @State private var fold: CGRect?
    /// True once a drag or pinch has placed the inset. Until then it follows the front camera.
    @State private var placed = false

    var body: some View {
        ZStack {
            // The whole screen, because the camera can lie outside the safe area.
            GeometryReader { screen in
                // The system reports the camera and the status strip without saying which is which.
                // The camera is the smaller one: 62x40 points at most, the strip 84x124 at least.
                let camera = screen.reservedRegions(kind: .occlusion).map(\.frame)
                    .min { $0.width * $0.height < $1.width * $1.height }
                let bend = screen.reservedRegions(kind: .division).first?.frame
                Color.black
                    .onChange(of: camera, initial: true) { lens = camera }
                    .onChange(of: bend, initial: true) {
                        print("fold: \(bend.map { "\($0)" } ?? "none")")
                        withAnimation(.easeInOut(duration: 0.3)) { fold = bend }
                    }
            }
            .ignoresSafeArea()
            // Laid out from the space the app is given, which changes when the phone folds or turns.
            GeometryReader { space in
                let origin = space.frame(in: .global).origin
                // The fold and the camera are measured on the whole screen; `Layout` wants them
                // in this space's own coordinates.
                let layout = Layout(
                    in: space.size, landscape: landscape,
                    fold: fold?.offsetBy(dx: -origin.x, dy: -origin.y),
                    lens: CGPoint(x: (lens?.midX ?? 0) - origin.x, y: (lens?.midY ?? 0) - origin.y)
                )
                let picture = layout.picture.offsetBy(dx: origin.x, dy: origin.y)
                preview(front: swapped)
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
                                            placed = true
                                            print("inset: center \(inset.center), size \(inset.size)")
                                        }
                                )
                                .accessibilityLabel("Swap cameras")
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                    .frame(width: layout.picture.width, height: layout.picture.height)
                    .position(x: layout.picture.midX, y: layout.picture.midY)
                    // The inset starts on the front camera, or in the corner nearest to it, so that
                    // looking at yourself is looking at the lens. It follows the camera through
                    // folds and turns until a drag or pinch places it.
                    .onChange(of: [lens, picture], initial: true) {
                        guard let lens, !placed else { return }
                        inset = Inset(near: CGPoint(
                            x: (lens.midX - picture.minX) / picture.width,
                            y: (lens.midY - picture.minY) / picture.height
                        ))
                        print("inset near the camera: center \(inset.center)")
                    }
                Button(action: { shoot(via: "screen button") }) {
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 2).padding(4))
                }
                .accessibilityLabel("Shutter")
                .frame(width: layout.shutter.width, height: layout.shutter.height)
                .position(x: layout.shutter.midX, y: layout.shutter.midY)
            }
        }
        .task {
            // Eased, so the picture changes shape along with the screen's own rotation.
            camera.onTurn = { turned in withAnimation(.easeInOut(duration: 0.3)) { landscape = turned } }
            camera.onBlank = { blank = $0 }
            await camera.start()
        }
        // The volume buttons (and other hardware capture buttons) fire the shutter on release.
        .onCameraCaptureEvent { event in
            if event.phase == .ended { shoot(via: "hardware button") }
        }
        .sheet(item: $shot) { shot in
            ShareSheet(image: shot.image).onAppear { print("share sheet shown") }
        }
    }

    /// One camera's live picture. While the cameras deliver blank frames, which they do when
    /// Xcode's Device Hub controls the phone, it gets a colored layer and a letter instead:
    /// red F for the front camera, green B for the back. Otherwise both pictures are black.
    private func preview(front: Bool) -> some View {
        Preview(layer: front ? camera.frontPreview : camera.rearPreview)
            .overlay {
                if blank {
                    (front ? Color.red : Color.green).opacity(0.4)
                        .overlay {
                            // The letter is turned as far as the camera's picture is from upright,
                            // so a sideways camera shows a sideways letter. Checked twice a second.
                            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                                Text(front ? "F" : "B")
                                    .font(.system(size: 200, weight: .bold))
                                    .minimumScaleFactor(0.1)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .rotationEffect(.degrees(camera.tilt(front: front)))
                            }
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
