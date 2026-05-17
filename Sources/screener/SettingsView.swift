import SwiftUI

struct SettingsView: View {
    @AppStorage("videoDirectory") private var videoDirectory = "~/Documents/interesting-videos/"
    @AppStorage("modelName") private var modelName = "gemini-3.1-flash-lite"
    @AppStorage("gcpProject") private var gcpProject = ""
    @AppStorage("gcpLocation") private var gcpLocation = "global"
    @AppStorage("environment") private var environment = "prod"
    
    var body: some View {
        Form {
            Section(header: Text("General Settings")) {
                TextField("Video Directory", text: $videoDirectory)
                    .textFieldStyle(.roundedBorder)
                    .help("Path to the directory containing videos.")
                
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
        }
        .padding(20)
        .frame(width: 400)
    }
}
