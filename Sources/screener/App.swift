import SwiftUI
import AVKit
import SwiftData

@main
struct ScreenerApp: App {
    init() {
        // Workaround for macOS VideoPlayer crash: force linking AVKit
        #if os(macOS)
        _ = AVPlayerView.self
        #endif
    }
    
    var body: some Scene {
        WindowGroup("Video Screener") {
            ContentView()
        }
        .modelContainer(for: VideoMetadata.self)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
