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
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            GeminiSettingsView()
                .tabItem {
                    Label("Gemini", systemImage: "sparkles")
                }
                
            DatabaseSettingsView()
                .tabItem {
                    Label("Database", systemImage: "server.rack")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var directoryManager = DirectoryManager.shared
    @AppStorage("autoPlayVideos") private var autoPlayVideos = false
    
    @State private var newDirectoryPath: String = ""
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Auto-Play Videos", isOn: $autoPlayVideos)
                    .help("Automatically start playing a video when selected.")
                
                Divider().padding(.vertical, 4)
                
                Text("Video Source Directories")
                    .font(.headline)
                
                List {
                    ForEach(directoryManager.directories, id: \.self) { directory in
                        HStack {
                            Text(directory)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: {
                                directoryManager.removeDirectory(directory)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .opacity(0.8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        directoryManager.removeDirectory(at: offsets)
                    }
                }
                .frame(minHeight: 140)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                HStack {
                    Spacer()
                    Button(action: {
                        selectDirectory()
                    }) {
                        Image(systemName: "plus.folder")
                        Text("Add Directory...")
                    }
                }
            }
        }
        .padding(20)
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.message = "Choose a directory containing videos"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                directoryManager.addDirectory(url.path)
            }
        }
    }
}

struct GeminiSettingsView: View {
    @AppStorage("modelName") private var modelName = "gemini-3.1-flash-lite"
    @AppStorage("gcpProject") private var gcpProject = ""
    @AppStorage("gcpLocation") private var gcpLocation = "global"
    @AppStorage("environment") private var environment = "prod"
    @AppStorage("showDebugSettings") private var showDebugSettings = false

    var body: some View {
        Form {
            TextField("Model Name:", text: $modelName)
                .textFieldStyle(.roundedBorder)
                .help("The Gemini model to use for video description.")
            
            TextField("Google Cloud Project:", text: $gcpProject, prompt: Text("Uses gcloud config if empty"))
                .textFieldStyle(.roundedBorder)
                .help("Google Cloud Project ID. If empty, uses gcloud config.")
            
            TextField("Google Cloud Location:", text: $gcpLocation, prompt: Text("e.g., global, us-central1"))
                .textFieldStyle(.roundedBorder)
                .help("Google Cloud Location (e.g., global, us-central1).")
            
            if showDebugSettings {
                Divider().padding(.vertical, 4)
                
                Picker("Environment:", selection: $environment) {
                    Text("Production").tag("prod")
                    Text("Staging").tag("staging")
                    Text("Autopush").tag("autopush")
                }
                .pickerStyle(.menu)
                .help("The AI Platform environment to use.")
            }
        }
        .padding(20)
    }
}

import SwiftData

struct DatabaseSettingsView: View {
    @Query private var allMetadata: [VideoMetadata]
    
    var body: some View {
        Form {
            Section(header: Text("Database Health")) {
                let totalRecords = allMetadata.count
                let textIndexed = allMetadata.filter { $0.localTextVectorData != nil }.count
                let visualIndexed = allMetadata.filter { $0.cloudVisualVectorData != nil }.count
                let summaries = allMetadata.filter { $0.summary != nil }.count
                let c2paRecords = allMetadata.filter { $0.hasC2PA == true }.count
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Total Videos Tracked:")
                        Spacer()
                        Text("\(totalRecords)")
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Gemini Summaries Generated:")
                        Spacer()
                        Text("\(summaries)")
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Local Text Embeddings:")
                        Spacer()
                        Text("\(textIndexed)")
                            .foregroundColor(textIndexed > 0 ? .green : .primary)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Cloud Visual Embeddings:")
                        Spacer()
                        Text("\(visualIndexed)")
                            .foregroundColor(visualIndexed > 0 ? .green : .primary)
                            .fontWeight(.bold)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("C2PA Credentials Found:")
                        Spacer()
                        Text("\(c2paRecords)")
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
    }
}
