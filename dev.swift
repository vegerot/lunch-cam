#!/usr/bin/env swift

// Lunch Cam developer commands for the paired iPhone. Run `./dev.swift` to see the usage.
import Foundation

let device = "00008160-0001393420434036" // "iPhone Duo Max"
let app = "com.vegerot.lunchcam"
let usage = """
    usage:
      dev.swift install [--console]  Build, install and launch on the iPhone. Unlock the phone first.
                                     --console keeps showing the app's output; stopping it stops the app.
      dev.swift photo [file]         Copy the last photo the app took to file (default: last.jpg).
                                     The app keeps that debug copy; delete this command when the copy goes.
    """

/// Runs a command with this script's input and output. Exits with the command's status if it fails.
func run(_ command: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = command
    try! process.run() // `/usr/bin/env` exists on every Mac
    process.waitUntilExit()
    if process.terminationStatus != 0 { exit(process.terminationStatus) }
}

/// Replaces this script with a command, so that stopping the script stops the command.
/// A command started with `run` would keep running as an orphan (seen with `install --console`).
func become(_ command: [String]) -> Never {
    let argv = command.map { strdup($0) } + [nil]
    execvp(command[0], argv)
    fatalError("could not start \(command[0]): \(String(cString: strerror(errno)))")
}

// The paths below are relative to the project directory, which is where this script lives.
let projectDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
FileManager.default.changeCurrentDirectoryPath(projectDirectory)

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "install":
    run([
        "xcodebuild", "-project", "LunchCam.xcodeproj", "-scheme", "LunchCam", "-configuration", "Debug",
        "-destination", "id=\(device)", "-derivedDataPath", "build", "-allowProvisioningUpdates",
        "-quiet", "build",
    ])
    run([
        "xcrun", "devicectl", "device", "install", "app", "--device", device,
        "build/Build/Products/Debug-iphoneos/LunchCam.app",
    ])
    let console = arguments.contains("--console") ? ["--console"] : []
    become(["xcrun", "devicectl", "device", "process", "launch", "--device", device, "--terminate-existing"]
        + console + [app])
case "photo":
    let file = arguments.count > 1 ? arguments[1] : "last.jpg"
    run([
        "xcrun", "devicectl", "device", "copy", "from", "--device", device,
        "--domain-type", "appDataContainer", "--domain-identifier", app,
        "--source", "Documents/last.jpg", "--destination", file,
    ])
    run(["sips", "--getProperty", "pixelWidth", "--getProperty", "pixelHeight", file])
default:
    print(usage)
    exit(2)
}
