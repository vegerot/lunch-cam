import Foundation

// Tests for `Metadata`, run on the Mac with `./dev test`. Expected values are written out by hand.

func expect(_ name: String, _ actual: String, _ expected: String) {
    let same = actual == expected
    print("\(same ? "✅" : "❌") \(name)\(same ? "" : ": got \(actual), expected \(expected)")")
    if !same { failures += 1 }
}

func metadataTests() {
    // Photo files store a place as positive numbers plus a letter for the hemisphere.
    // Sydney is south and east; its harbour is at sea level or just above.
    let sydney = Metadata.place(latitude: -33.5, longitude: 151.25, altitude: 12)
    expect("south and east", "\(sydney["Latitude"]!) \(sydney["LatitudeRef"]!) \(sydney["Longitude"]!) \(sydney["LongitudeRef"]!)",
           "33.5 S 151.25 E")
    expect("above the sea is reference 0", "\(sydney["Altitude"]!) \(sydney["AltitudeRef"]!)", "12.0 0")
    // The Dead Sea shore is north and east, and below sea level.
    let deadSea = Metadata.place(latitude: 31.5, longitude: 35.5, altitude: -430)
    expect("north, and below the sea is reference 1",
           "\(deadSea["Latitude"]!) \(deadSea["LatitudeRef"]!) \(deadSea["Altitude"]!) \(deadSea["AltitudeRef"]!)",
           "31.5 N 430.0 1")
    // San Francisco is north and west.
    let sanFrancisco = Metadata.place(latitude: 37.75, longitude: -122.5, altitude: 0)
    expect("west", "\(sanFrancisco["Longitude"]!) \(sanFrancisco["LongitudeRef"]!)", "122.5 W")

    // The camera names its lens "<phone> back camera ..." or "<phone> front camera ...".
    expect("the phone's name comes from the rear lens", Metadata.model(lens: "iPhone Duo back camera 5.96mm f/1.6"), "iPhone Duo")
    expect("or from the front lens", Metadata.model(lens: "iPhone 15 Pro front camera 2.69mm f/1.9"), "iPhone 15 Pro")
}
