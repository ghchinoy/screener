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

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

struct MetadataInspectorView: View {
    @Bindable var metadata: VideoMetadata
    @Binding var showingC2PADetails: Bool
    var onUpdate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            GroupBox("Technical Info") {
                VStack(alignment: .leading, spacing: 8) {
                    if let duration = metadata.duration {
                        InfoRow(title: "Duration", value: String(format: "%.2fs", duration))
                    }
                    if let width = metadata.width, let height = metadata.height {
                        InfoRow(title: "Dimensions", value: "\(Int(width))x\(Int(height))")
                        
                        let ratio = width / height
                        let formatRatio = String(format: "%.2f:1", ratio)
                        InfoRow(title: "Aspect", value: formatRatio)
                    }
                    if let fps = metadata.frameRate {
                        InfoRow(title: "FPS", value: String(format: "%.2f", fps))
                    }
                    if let hasAudio = metadata.hasAudio {
                        InfoRow(title: "Audio", value: hasAudio ? "Yes" : "No")
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let hasC2PA = metadata.hasC2PA {
                GroupBox("Content Credentials") {
                    if hasC2PA {
                        HStack {
                            if let imagePath = Bundle.module.path(forResource: "c2pa-icon", ofType: "png"),
                               let nsImage = NSImage(contentsOfFile: imagePath) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading) {
                                if let issuer = metadata.c2paIssuer {
                                    Text("Issued by: \(issuer)").font(.subheadline).fontWeight(.medium)
                                }
                                if let tool = metadata.c2paTool {
                                    Text("Tool: \(tool)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Details") {
                                showingC2PADetails = true
                            }
                        }
                        .padding(4)
                    } else {
                        Text("No Content Credentials found.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            
            GroupBox("Comments") {
                TextEditor(text: $metadata.comments)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .onChange(of: metadata.comments) { _, _ in
                        onUpdate()
                    }
            }
            
            if metadata.summary != nil {
                GroupBox("Gemini Analysis") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let summary = metadata.summary {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Summary").font(.caption).foregroundColor(.secondary)
                                Text(summary).textSelection(.enabled)
                            }
                        }
                        
                        if let mood = metadata.colorMood {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color / Mood").font(.caption).foregroundColor(.secondary)
                                Text(mood).textSelection(.enabled)
                            }
                        }
                        
                        if let motion = metadata.motionType {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Motion Type").font(.caption).foregroundColor(.secondary)
                                Text(motion).textSelection(.enabled)
                            }
                        }
                        
                        if let transcript = metadata.transcript, transcript != "No speech" && transcript != "" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transcript").font(.caption).foregroundColor(.secondary)
                                Text(transcript).textSelection(.enabled)
                            }
                        }
                        
                        if let safety = metadata.contentSafety {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Content Safety").font(.caption).foregroundColor(.secondary)
                                Text(safety).textSelection(.enabled)
                            }
                        }
                        
                        if !metadata.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(metadata.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
