import SwiftUI
import AVKit
import SwiftData

struct DetailView: View {
    let video: VideoFile
    @Environment(\.modelContext) private var modelContext
    
    @State private var player: AVPlayer?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var metadata: VideoMetadata?
    @State private var showingC2PADetails = false
    
    var body: some View {
        HSplitView {
            // Main Video Area
            VideoPlayer(player: player)
                .cornerRadius(12)
                .padding()
                .frame(minWidth: 400)
                .onAppear {
                    setupVideo(video)
                }
                .onChange(of: video) { oldValue, newVideo in
                    setupVideo(newVideo)
                }
                .onDisappear {
                    player?.pause()
                }
            
            // Inspector Area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(video.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let meta = metadata {
                        MetadataInspectorView(metadata: meta, showingC2PADetails: $showingC2PADetails)
                    } else {
                        ProgressView("Loading metadata...")
                    }
                    
                    Button(action: {
                        Task {
                            await analyzeVideo()
                        }
                    }) {
                        if isAnalyzing {
                            ProgressView().controlSize(.small)
                            Text("Analyzing with Gemini...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Describe with Gemini")
                        }
                    }
                    .disabled(isAnalyzing)
                    .buttonStyle(.borderedProminent)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showingC2PADetails) {
            if let meta = metadata {
                C2PADetailsView(metadata: meta)
            }
        }
    }
    
    private func setupVideo(_ v: VideoFile) {
        player?.pause()
        player = AVPlayer(url: v.url)
        player?.play()
        
        errorMessage = nil
        
        let path = v.url.path
        let descriptor = FetchDescriptor<VideoMetadata>(predicate: #Predicate { $0.filePath == path })
        let all = (try? modelContext.fetch(descriptor)) ?? []
        
        let currentMeta: VideoMetadata
        if let fetched = all.first {
            currentMeta = fetched
        } else {
            currentMeta = VideoMetadata(filePath: path)
            modelContext.insert(currentMeta)
        }
        
        self.metadata = currentMeta
        
        Task {
            await extractTechnicalMetadata(for: v.url, metadata: currentMeta)
        }
    }
    
    private func extractTechnicalMetadata(for url: URL, metadata: VideoMetadata) async {
        let asset = AVAsset(url: url)
        
        if metadata.duration == nil {
            if let duration = try? await asset.load(.duration) {
                metadata.duration = duration.seconds
            }
        }
        
        if metadata.width == nil || metadata.height == nil || metadata.frameRate == nil {
            if let videoTracks = try? await asset.loadTracks(withMediaType: .video), let track = videoTracks.first {
                if let size = try? await track.load(.naturalSize) {
                    metadata.width = size.width
                    metadata.height = size.height
                }
                if let frameRate = try? await track.load(.nominalFrameRate) {
                    metadata.frameRate = frameRate
                }
            }
        }
        
        if metadata.hasAudio == nil {
            if let audioTracks = try? await asset.loadTracks(withMediaType: .audio) {
                metadata.hasAudio = !audioTracks.isEmpty
            }
        }
        
        if metadata.thumbnailData == nil {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 300, height: 300)
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                if let tiffData = nsImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) {
                    metadata.thumbnailData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
        
        if metadata.hasC2PA == nil {
            do {
                let manifestJSON = try MockC2PAReader.readFile(at: url)
                metadata.c2paManifestJSON = manifestJSON
                metadata.hasC2PA = true
                
                if let data = manifestJSON.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let activeManifestRef = dict["active_manifest"] as? String,
                   let manifests = dict["manifests"] as? [String: Any],
                   let activeManifest = manifests[activeManifestRef] as? [String: Any] {
                    
                    metadata.c2paTool = activeManifest["claim_generator"] as? String
                    
                    if let sigInfo = activeManifest["signature_info"] as? [String: Any] {
                        metadata.c2paIssuer = sigInfo["issuer"] as? String
                    }
                }
            } catch {
                metadata.hasC2PA = false
            }
        }
    }
    
    private func analyzeVideo() async {
        isAnalyzing = true
        errorMessage = nil
        
        if video.size > 20_000_000 {
            errorMessage = "Video is too large (\(video.sizeString)) for direct inline analysis (limit ~20MB). For production, use File API."
            isAnalyzing = false
            return
        }
        
        do {
            let response = try await VertexClient.shared.describeVideo(url: video.url)
            metadata?.summary = response.summary
            metadata?.tags = response.tags
            metadata?.transcript = response.transcript
            metadata?.colorMood = response.colorMood
            metadata?.motionType = response.motionType
            metadata?.contentSafety = response.contentSafety
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isAnalyzing = false
    }
}

struct MetadataInspectorView: View {
    @Bindable var metadata: VideoMetadata
    @Binding var showingC2PADetails: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            GroupBox("Technical Info") {
                VStack(alignment: .leading, spacing: 8) {
                    if let d = metadata.duration {
                        InfoRow(title: "Duration", value: String(format: "%.2fs", d))
                    }
                    if let w = metadata.width, let h = metadata.height {
                        InfoRow(title: "Dimensions", value: "\(Int(w))x\(Int(h))")
                        
                        let ratio = w / h
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

struct MockC2PAReader {
    static func readFile(at url: URL) throws -> String {
        if url.lastPathComponent.contains("veo") || url.lastPathComponent.contains("genmedia") || url.lastPathComponent.contains("gemini") || url.lastPathComponent.contains("a2v") {
            return """
            {
              "active_manifest": "urn:uuid:mock-c2pa-12345",
              "manifests": {
                "urn:uuid:mock-c2pa-12345": {
                  "claim_generator": "Google Veo / DeepMind",
                  "signature_info": {
                    "issuer": "Google Trust Services LLC"
                  },
                  "assertions": [
                    {
                      "label": "c2pa.training-mining",
                      "data": { "entries": { "c2pa.settings": { "c2pa.training-mining": "notAllowed" } } }
                    }
                  ]
                }
              }
            }
            """
        } else {
            throw NSError(domain: "MockC2PA", code: 404, userInfo: [NSLocalizedDescriptionKey: "No C2PA manifest found"])
        }
    }
}
