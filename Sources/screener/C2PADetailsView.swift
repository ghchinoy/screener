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

struct C2PADetailsView: View {
    let metadata: VideoMetadata
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Content Credentials (C2PA)")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let thumb = metadata.thumbnailData, let nsImage = NSImage(data: thumb) {
                        HStack {
                            Spacer()
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(8)
                            Spacer()
                        }
                    }
                    
                    GroupBox("Signature Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(title: "Status", value: "Valid (Cryptographically Signed)")
                            if let issuer = metadata.c2paIssuer {
                                InfoRow(title: "Issuer", value: issuer)
                            }
                            if let tool = metadata.c2paTool {
                                InfoRow(title: "Software", value: tool)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let json = metadata.c2paManifestJSON {
                        GroupBox("Raw Manifest JSON") {
                            Text(json)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}
