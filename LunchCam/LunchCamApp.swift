import SwiftUI

@main
struct LunchCamApp: App {
    var body: some Scene {
        WindowGroup {
            ProbeView()
        }
    }
}

/// Layer 1: shows the multi-camera report on screen and prints it, so the Mac can read it
/// with `devicectl device process launch --console`.
struct ProbeView: View {
    private let report = multiCamReport()

    var body: some View {
        ScrollView {
            Text(report)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .onAppear { print(report) }
    }
}
