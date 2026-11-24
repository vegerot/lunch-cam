import Foundation
import ImageIO

/// The details stored inside a photo file next to the picture: when, where and with what it was taken.
enum Metadata {
    /// Everything that goes into the file.
    /// `exif` is the camera's own record of the full-frame picture (time, exposure, lens), which
    /// every frame carries. `place` is the result of `place(latitude:longitude:altitude:)`, if known.
    static func properties(exif: [String: Any], width: Int, height: Int, place: [String: Any]?) -> [String: Any] {
        var exif = exif
        // The camera wrote its frame's size, before the frame was turned upright.
        exif[kCGImagePropertyExifPixelXDimension as String] = width
        exif[kCGImagePropertyExifPixelYDimension as String] = height
        var tiff: [String: Any] = [
            kCGImagePropertyTIFFMake as String: "Apple",
            kCGImagePropertyTIFFSoftware as String: "Lunch Cam",
        ]
        if let lens = exif[kCGImagePropertyExifLensModel as String] as? String {
            tiff[kCGImagePropertyTIFFModel as String] = model(lens: lens)
        }
        var all: [String: Any] = [
            kCGImagePropertyExifDictionary as String: exif,
            kCGImagePropertyTIFFDictionary as String: tiff,
        ]
        all[kCGImagePropertyGPSDictionary as String] = place
        return all
    }

    /// A place the way photo files store it: positive numbers, with a letter for the hemisphere
    /// and a 0 or 1 for above or below sea level. Altitude is in meters.
    static func place(latitude: Double, longitude: Double, altitude: Double) -> [String: Any] {
        [
            kCGImagePropertyGPSLatitude as String: abs(latitude),
            kCGImagePropertyGPSLatitudeRef as String: latitude < 0 ? "S" : "N",
            kCGImagePropertyGPSLongitude as String: abs(longitude),
            kCGImagePropertyGPSLongitudeRef as String: longitude < 0 ? "W" : "E",
            kCGImagePropertyGPSAltitude as String: abs(altitude),
            kCGImagePropertyGPSAltitudeRef as String: altitude < 0 ? 1 : 0,
        ]
    }

    /// The phone's name, which the camera puts at the start of its lens name:
    /// "iPhone Duo back camera 5.96mm f/1.6" gives "iPhone Duo".
    static func model(lens: String) -> String {
        lens.replacing(#/ (back|front) camera.+/#, with: "")
    }
}
