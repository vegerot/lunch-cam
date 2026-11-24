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

    init(in space: CGSize, landscape: Bool = false) {
        let shape = landscape ? 4.0 / 3 : 3.0 / 4 // width over height
        // The strip goes below the picture or beside it, whichever leaves the larger picture.
        let widthWithStripBelow = min(space.width, (space.height - Layout.strip) * shape)
        let widthWithStripBeside = min(space.width - Layout.strip, space.height * shape)
        let below = widthWithStripBelow >= widthWithStripBeside
        let width = max(widthWithStripBelow, widthWithStripBeside)
        let height = width / shape
        // The picture and the strip are centered together.
        let size = CGSize(width: Layout.shutterSize, height: Layout.shutterSize)
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
}
