import CoreGraphics

// Tests for `Layout`, run on the Mac with `./dev test`.
// Expected rectangles are worked out by hand. The shutter is 72 wide in a strip of 96.

func layoutTests() {
    // Twice as tall as wide. The picture takes the full width: 300 wide, so 400 tall (3:4).
    // Picture plus strip is 496 tall, centered in 600: it starts at (600 - 496) / 2 = 52.
    // The shutter's center is 48 below the picture's bottom edge (452): y = 500, x = 150.
    let tall = Layout(in: CGSize(width: 300, height: 600))
    expect("tall space: the picture fills the width", tall.picture,
           CGRect(x: 0, y: 52, width: 300, height: 400))
    expect("tall space: the shutter sits below the picture", tall.shutter,
           CGRect(x: 114, y: 464, width: 72, height: 72))

    // Wide, like the open inner display. A strip below would leave a picture only
    // (600 - 96) * 3/4 = 378 wide; a strip beside leaves the full height: 600 tall, 450 wide.
    // Picture plus strip is 546 wide, centered in 1000: it starts at (1000 - 546) / 2 = 227.
    // The shutter's center is 48 right of the picture's right edge (677): x = 725, y = 300.
    let wide = Layout(in: CGSize(width: 1000, height: 600))
    expect("wide space: the picture fills the height", wide.picture,
           CGRect(x: 227, y: 0, width: 450, height: 600))
    expect("wide space: the shutter sits beside the picture", wide.shutter,
           CGRect(x: 689, y: 264, width: 72, height: 72))

    // Nearly the picture's own shape, like the closed outer display: no spare room either way.
    // The picture shrinks to make room. Strip below: (540 - 96) * 3/4 = 333 wide, 444 tall.
    // Strip beside: only 390 - 96 = 294 wide. Below wins. Centered across: (390 - 333) / 2 = 28.5.
    // Picture plus strip fills the height, so it starts at 0. Shutter center: (195, 444 + 48).
    let snug = Layout(in: CGSize(width: 390, height: 540))
    expect("snug space: the picture shrinks to make room", snug.picture,
           CGRect(x: 28.5, y: 0, width: 333, height: 444))
    expect("snug space: the shutter does not cover the picture", snug.shutter,
           CGRect(x: 159, y: 456, width: 72, height: 72))

    // The phone held sideways gives a 4:3 picture. In the same wide space, a strip below would
    // leave (600 - 96) * 4/3 = 672 wide; a strip beside leaves the full height: 600 tall, 800 wide.
    // Picture plus strip is 896 wide, centered in 1000: it starts at 52.
    // The shutter's center is 48 right of the picture's right edge (852): x = 900, y = 300.
    let sideways = Layout(in: CGSize(width: 1000, height: 600), landscape: true)
    expect("sideways: the picture is 4:3", sideways.picture,
           CGRect(x: 52, y: 0, width: 800, height: 600))
    expect("sideways: the shutter sits beside the picture", sideways.shutter,
           CGRect(x: 864, y: 264, width: 72, height: 72))

    // Half-folded like a book: a fold 40 wide down the middle of the same wide space, and the
    // cameras on the right half (x 520 to 1000, so 480 wide). The picture takes that half's
    // full height: 600 tall, 450 wide, centered in the half: x = 520 + (480 - 450) / 2 = 535.
    // The shutter is centered in the other half (x 0 to 480): center (240, 300).
    let book = Layout(in: CGSize(width: 1000, height: 600),
                      fold: CGRect(x: 480, y: 0, width: 40, height: 600), lens: CGPoint(x: 700, y: 40))
    expect("book: the picture is on the cameras' half", book.picture,
           CGRect(x: 535, y: 0, width: 450, height: 600))
    expect("book: the shutter is on the other half", book.shutter,
           CGRect(x: 204, y: 264, width: 72, height: 72))

    // Half-folded on a table: the fold runs across, and the cameras are on the top half
    // (y 0 to 480). The picture takes that half's height: 480 tall, 360 wide, x = (600 - 360) / 2.
    // The shutter is centered in the bottom half (y 520 to 1000): center (300, 760).
    let table = Layout(in: CGSize(width: 600, height: 1000),
                       fold: CGRect(x: 0, y: 480, width: 600, height: 40), lens: CGPoint(x: 40, y: 300))
    expect("table: the picture is on the cameras' half", table.picture,
           CGRect(x: 120, y: 0, width: 360, height: 480))
    expect("table: the shutter is on the other half", table.shutter,
           CGRect(x: 264, y: 724, width: 72, height: 72))

    // The same table with the cameras on the bottom half: the two change places.
    let turned = Layout(in: CGSize(width: 600, height: 1000),
                        fold: CGRect(x: 0, y: 480, width: 600, height: 40), lens: CGPoint(x: 40, y: 700))
    expect("table, cameras below: the picture is on the bottom half", turned.picture,
           CGRect(x: 120, y: 520, width: 360, height: 480))
    expect("table, cameras below: the shutter is on the top half", turned.shutter,
           CGRect(x: 264, y: 204, width: 72, height: 72))

    // Split view on a half-folded phone: the app has one half of the screen, and the fold lies on
    // the edge of its space, with 10 points of space past it. That is no room for a shutter, so the
    // fold is ignored and the space is laid out as usual. Strip below: (600 - 96) * 3/4 = 378 wide.
    // Strip beside: 480 - 96 = 384 wide, 512 tall. Beside wins and fills the width, so x = 0;
    // y = (600 - 512) / 2 = 44. The shutter's center is 48 right of the picture: (432, 300).
    let split = Layout(in: CGSize(width: 480, height: 600),
                       fold: CGRect(x: 470, y: 0, width: 40, height: 600), lens: CGPoint(x: 40, y: 300))
    expect("split view: a fold on the edge is ignored", split.picture,
           CGRect(x: 0, y: 44, width: 384, height: 512))
    expect("split view: the shutter stays inside the space", split.shutter,
           CGRect(x: 396, y: 264, width: 72, height: 72))
}
