import CoreGraphics

/// Where the picture and the shutter go in the space the app is given.
/// The shutter gets a strip of its own next to the picture, so it never covers the picture.
struct Layout {
    /// The picture: 3:4, or 4:3 when the phone is held sideways.
    let picture: CGRect
    /// The shutter button.
    let shutter: CGRect

    static let shutterSize = 72.0
    /// The width of the shutter's strip: the shutter with 12 of room on each side.
    static let strip = 96.0

    /// `fold` is the band where a half-folded phone bends, and `lens` a point on the front camera,
    /// both in the same coordinates as `space`. With a fold, the picture goes on the half that
    /// holds the cameras and the shutter on the other half.
    init(in space: CGSize, landscape: Bool = false, fold: CGRect? = nil, lens: CGPoint = .zero) {
        let shape = landscape ? 4.0 / 3 : 3.0 / 4 // width over height
        let size = CGSize(width: Layout.shutterSize, height: Layout.shutterSize)
        // The fold crosses the whole space one way; the two halves lie on either side of it.
        // It only counts when each half has room for the shutter. In split view the app has one
        // half of the screen, and the fold lies on the edge of its space.
        if let fold, case let (first, second) = Layout.halves(of: space, around: fold),
           min(first.width, first.height, second.width, second.height) >= Layout.strip {
            let camerasFirst = first.contains(lens)
            let home = camerasFirst ? first : second
            let other = camerasFirst ? second : first
            let width = min(home.width, home.height * shape)
            picture = CGRect(x: home.midX - width / 2, y: home.midY - width / shape / 2,
                             width: width, height: width / shape)
            shutter = CGRect(origin: CGPoint(x: other.midX - size.width / 2, y: other.midY - size.height / 2),
                             size: size)
            return
        }
        // The strip goes below the picture or beside it, whichever leaves the larger picture.
        let widthWithStripBelow = min(space.width, (space.height - Layout.strip) * shape)
        let widthWithStripBeside = min(space.width - Layout.strip, space.height * shape)
        let below = widthWithStripBelow >= widthWithStripBeside
        let width = max(widthWithStripBelow, widthWithStripBeside)
        let height = width / shape
        // The picture and the strip are centered together.
        if below {
            let top = (space.height - height - Layout.strip) / 2
            picture = CGRect(x: (space.width - width) / 2, y: top, width: width, height: height)
            shutter = CGRect(
                origin: CGPoint(x: picture.midX - size.width / 2, y: picture.maxY + (Layout.strip - size.height) / 2),
                size: size
            )
        } else {
            let left = (space.width - width - Layout.strip) / 2
            picture = CGRect(x: left, y: (space.height - height) / 2, width: width, height: height)
            shutter = CGRect(
                origin: CGPoint(x: picture.maxX + (Layout.strip - size.width) / 2, y: picture.midY - size.height / 2),
                size: size
            )
        }
    }

    /// The parts of `space` before and after `fold`.
    private static func halves(of space: CGSize, around fold: CGRect) -> (CGRect, CGRect) {
        let whole = CGRect(origin: .zero, size: space)
        let across = fold.width >= space.width
        return across
            ? (whole.divided(atDistance: max(fold.minY, 0), from: .minYEdge).slice,
               whole.divided(atDistance: max(fold.maxY, 0), from: .minYEdge).remainder)
            : (whole.divided(atDistance: max(fold.minX, 0), from: .minXEdge).slice,
               whole.divided(atDistance: max(fold.maxX, 0), from: .minXEdge).remainder)
    }
}
