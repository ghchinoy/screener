import SwiftUI
import AppKit

struct SettingsView: View {
    var body: some View {
        TabView {
            DirectoriesSettingsView()
                .tabItem {
                    Label("Directories", systemImage: "folder")
                }
            
            GeminiSettingsView()
                .tabItem {
                    Label("Gemini", systemImage: "sparkles")
                }
        }
        .frame(width: 500, height: 350) // Increased frame size for better layout
    }
}

struct DirectoriesSettingsView: View {
    @ObservedObject private var directoryManager = DirectoryManager.shared
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 12) {
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
                .frame(minHeight: 180)
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

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Model Name")
                    TextField("", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .help("The Gemini model to use for video description.")
                }
                
                VStack(alignment: .leading) {
                    Text("GCP Project")
                    TextField("Uses gcloud config if empty", text: $gcpProject)
                        .textFieldStyle(.roundedBorder)
                        .help("GCP Project ID. If empty, uses gcloud config.")
                }
                
                VStack(alignment: .leading) {
                    Text("GCP Location")
                    TextField("e.g., global, us-central1", text: $gcpLocation)
                        .textFieldStyle(.roundedBorder)
                        .help("GCP Location (e.g., global, us-central1).")
                }
                
                HStack {
                    Text("Environment:")
                    Picker("", selection: $environment) {
                        Text("Production").tag("prod")
                        Text("Staging").tag("staging")
                        Text("Autopush").tag("autopush")
                    }
                    .pickerStyle(.menu)
                    .help("The AI Platform environment to use.")
                }
            }
        }
        .padding(20)
    }
}
