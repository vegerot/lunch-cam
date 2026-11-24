import CoreGraphics
import Foundation

// Tests for `Inset`, and the entry point for all tests, run on the Mac with `./dev test`.
// Expected rectangles are worked out by hand for a 1440x1920 photo, the size the cameras deliver.

let photo = CGSize(width: 1440, height: 1920)
var failures = 0

func expect(_ name: String, _ actual: CGRect, _ expected: CGRect) {
    let close = abs(actual.minX - expected.minX) < 0.01 && abs(actual.minY - expected.minY) < 0.01
        && abs(actual.width - expected.width) < 0.01 && abs(actual.height - expected.height) < 0.01
    print("\(close ? "✅" : "❌") \(name)\(close ? "" : ": got \(actual), expected \(expected)")")
    if !close { failures += 1 }
}

@main
enum InsetTests {
    static func main() {
        // A quarter of the photo, 3% of the photo away from the top-left corner.
        expect("starts in the top-left corner", Inset().frame(in: photo),
               CGRect(x: 43.2, y: 57.6, width: 360, height: 480))
        // Half the photo right and down: 0.5 * 1440 = 720 and 0.5 * 1920 = 960 added to the start.
        expect("a drag moves it", Inset().moved(by: CGSize(width: 0.5, height: 0.5)).frame(in: photo),
               CGRect(x: 763.2, y: 1017.6, width: 360, height: 480))
        // Dragged far past the bottom-right corner, it stops one margin short of both edges:
        // x = 1440 - 43.2 - 360, y = 1920 - 57.6 - 480.
        expect("a drag cannot leave the photo", Inset().moved(by: CGSize(width: 2, height: 2)).frame(in: photo),
               CGRect(x: 1036.8, y: 1382.4, width: 360, height: 480))
        expect("nor leave it at the top-left", Inset().moved(by: CGSize(width: -2, height: -2)).frame(in: photo),
               CGRect(x: 43.2, y: 57.6, width: 360, height: 480))
        // In the middle of the photo, a pinch grows it around its own center:
        // 0.25 * 1.6 = 0.4 of the photo, so 576x768, centered on (720, 960).
        let middle = Inset(center: CGPoint(x: 0.5, y: 0.5))
        expect("a pinch resizes it around its center", middle.scaled(by: 1.6).frame(in: photo),
               CGRect(x: 432, y: 576, width: 576, height: 768))
        // The size stops at half the photo (720x960) and at 15% of it (216x288).
        expect("a pinch cannot grow it past half the photo", middle.scaled(by: 10).frame(in: photo),
               CGRect(x: 360, y: 480, width: 720, height: 960))
        expect("nor shrink it below 15%", middle.scaled(by: 0.1).frame(in: photo),
               CGRect(x: 612, y: 816, width: 216, height: 288))
        // Grown in the top-left corner, it would poke out of the photo; it is pushed back in.
        expect("a pinch in a corner stays inside the photo", Inset().scaled(by: 2).frame(in: photo),
               CGRect(x: 43.2, y: 57.6, width: 720, height: 960))
        layoutTests()
        exit(failures == 0 ? 0 : 1)
    }
}
