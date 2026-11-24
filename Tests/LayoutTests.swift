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
}
