import SwiftUI

@main
struct InLANApp: App {
    @StateObject private var scanner = NetworkScanner()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(scanner)
                .preferredColorScheme(.dark)
        }
    }
}
