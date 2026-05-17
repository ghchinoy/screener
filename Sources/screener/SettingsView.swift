import SwiftUI

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
        .frame(width: 450, height: 300)
    }
}

struct DirectoriesSettingsView: View {
    @ObservedObject private var directoryManager = DirectoryManager.shared
    @State private var newDirectoryPath: String = ""
    
    var body: some View {
        Form {
            List {
                ForEach(directoryManager.directories, id: \.self) { directory in
                    HStack {
                        Text(directory)
                        Spacer()
                        Button(action: {
                            directoryManager.removeDirectory(directory)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .opacity(0.8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onDelete { offsets in
                    directoryManager.removeDirectory(at: offsets)
                }
            }
            .frame(height: 150)
            
            HStack {
                TextField("New Directory Path (e.g. ~/Movies)", text: $newDirectoryPath)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    directoryManager.addDirectory(newDirectoryPath)
                    newDirectoryPath = ""
                }
                .disabled(newDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }
}

struct GeminiSettingsView: View {
    @AppStorage("modelName") private var modelName = "gemini-3.1-flash-lite"
    @AppStorage("gcpProject") private var gcpProject = ""
    @AppStorage("gcpLocation") private var gcpLocation = "global"
    @AppStorage("environment") private var environment = "prod"

    var body: some View {
        Form {
            TextField("Model Name", text: $modelName)
                .textFieldStyle(.roundedBorder)
                .help("The Gemini model to use for video description.")
            
            TextField("GCP Project", text: $gcpProject)
                .textFieldStyle(.roundedBorder)
                .help("GCP Project ID. If empty, uses gcloud config.")
            
            TextField("GCP Location", text: $gcpLocation)
                .textFieldStyle(.roundedBorder)
                .help("GCP Location (e.g., global, us-central1).")
            
            Picker("Environment", selection: $environment) {
                Text("Production").tag("prod")
                Text("Staging").tag("staging")
                Text("Autopush").tag("autopush")
            }
            .pickerStyle(.menu)
            .help("The AI Platform environment to use.")
        }
        .padding(20)
    }
}
