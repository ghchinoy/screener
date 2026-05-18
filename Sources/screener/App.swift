// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import AVKit
import SwiftData

@main
struct ScreenerApp: App {
    @AppStorage("showDebugSettings") private var showDebugSettings = false
    
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
        .modelContainer(sharedModelContainer)
        .commands {
            CommandMenu("Developer") {
                Toggle("Show Debug Settings", isOn: $showDebugSettings)
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([VideoMetadata.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: VideoMigrationPlan.self, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
