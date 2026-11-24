import CoreGraphics

/// Where the small camera sits inside the photo.
/// Everything is a fraction of the photo, so the preview and the saved photo get the same answer
/// at their different sizes. The inset has the photo's own shape.
struct Inset {
    /// The inset's center: 0 is the photo's left or top edge, 1 its right or bottom edge.
    var center = CGPoint(x: Inset.margin + 0.125, y: Inset.margin + 0.125)
    /// The inset's width and height as a fraction of the photo's.
    var size = 0.25

    /// The limits a pinch can reach, as fractions of the photo.
    static let smallest = 0.15
    static let largest = 0.5
    /// The gap kept between the inset and the photo's edges, as a fraction of the photo.
    static let margin = 0.03
    /// The inset's corner radius as a fraction of the photo's width.
    static let cornerRadius = 0.03

    /// The inset after a drag. `translation` is a fraction of the photo, like `center`.
    func moved(by translation: CGSize) -> Inset {
        var inset = self
        inset.center.x += translation.width
        inset.center.y += translation.height
        return inset.keptInside()
    }

    /// The inset after a pinch that multiplied its size by `factor`.
    func scaled(by factor: Double) -> Inset {
        var inset = self
        inset.size = min(max(size * factor, Inset.smallest), Inset.largest)
        return inset.keptInside()
    }

    /// The inset in the corner of the photo nearest to its center, one margin from both edges.
    func inNearestCorner() -> Inset {
        var inset = self
        inset.center = CGPoint(x: center.x < 0.5 ? 0 : 1, y: center.y < 0.5 ? 0 : 1)
        return inset.keptInside()
    }

    /// The same inset, pushed back so that it stays one margin inside the photo.
    fileprivate func keptInside() -> Inset {
        var inset = self
        let nearest = Inset.margin + size / 2
        inset.center.x = min(max(center.x, nearest), 1 - nearest)
        inset.center.y = min(max(center.y, nearest), 1 - nearest)
        return inset
    }

    /// The inset's rectangle in a photo (or preview) of the given size.
    func frame(in photo: CGSize) -> CGRect {
        CGRect(
            x: (center.x - size / 2) * photo.width,
            y: (center.y - size / 2) * photo.height,
            width: size * photo.width,
            height: size * photo.height
        )
    }
}

extension Inset {
    /// A starting inset centered as near to `point` as the margin allows.
    /// `point` is a fraction of the photo, like `center`, and may lie outside the photo.
    init(near point: CGPoint) {
        self = Inset(center: point).keptInside()
    }
}
