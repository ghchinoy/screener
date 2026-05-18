import SwiftUI
import AVKit
import SwiftData

struct DetailView: View {
    let video: VideoFile
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var favoritesManager: FavoritesManager
    @AppStorage("autoPlayVideos") private var autoPlayVideos = false
    
    @State private var player: AVPlayer?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var metadata: VideoMetadata?
    @State private var showingC2PADetails = false
    @State private var showingInspector = true
    
    var body: some View {
        // Main Video Area
        VideoPlayer(player: player)
            .cornerRadius(12)
            .padding()
            .frame(minWidth: 400, minHeight: 600)
            .onAppear {
                setupVideo(video)
            }
            .onChange(of: video) { oldValue, newVideo in
                setupVideo(newVideo)
            }
            .onDisappear {
                player?.pause()
            }
            .inspector(isPresented: $showingInspector) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(video.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Button {
                            favoritesManager.toggle(videoPath: video.url.path)
                        } label: {
                            Image(systemName: favoritesManager.isFavorite(videoPath: video.url.path) ? "star.fill" : "star")
                                .foregroundColor(favoritesManager.isFavorite(videoPath: video.url.path) ? .yellow : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.title3)
                    }
                    
                    if let meta = metadata {
                        MetadataInspectorView(metadata: meta, showingC2PADetails: $showingC2PADetails, onUpdate: {
                            updateLocalEmbedding()
                        })
                    } else {
                        ProgressView("Loading metadata...")
                    }
                    
                    HStack(spacing: 12) {
                        if metadata?.localTextVector != nil {
                            Label("Text Indexed", systemImage: "text.book.closed.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("No Text Index", systemImage: "text.book.closed")
                                .foregroundColor(.secondary)
                        }
                        
                        if metadata?.cloudVisualVector != nil {
                            Label("Visual Indexed", systemImage: "eye.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("No Visual Index", systemImage: "eye.slash")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    
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
                            Text(metadata?.summary != nil ? "Re-analyze with Gemini" : "Describe with Gemini")
                        }
                    }
                    .disabled(isAnalyzing)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    
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
            .inspectorColumnWidth(min: 300, ideal: 350, max: 500)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Metadata Inspector")
            }
        }
        .sheet(isPresented: $showingC2PADetails) {
            if let meta = metadata {
                C2PADetailsView(metadata: meta)
            }
        }
    }
    
    private func setupVideo(_ video: VideoFile) {
        player?.pause()
        player = AVPlayer(url: video.url)
        if autoPlayVideos {
            player?.play()
        }
        
        errorMessage = nil
        
        let path = video.url.path
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
            await extractTechnicalMetadata(for: video.url, metadata: currentMeta)
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
                let manifestJSON = try C2PACLIReader.readFile(at: url)
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
    
    private func updateLocalEmbedding() {
        guard let meta = metadata else { return }
        let textParts = [
            meta.summary,
            meta.tags.joined(separator: ", "),
            meta.colorMood,
            meta.motionType,
            meta.transcript,
            meta.comments
        ].compactMap { $0 }.filter { !$0.isEmpty }
        
        let fullText = textParts.joined(separator: " . ")
        if let vector = SemanticSearchManager.shared.getLocalTextEmbedding(for: fullText) {
            meta.localTextVector = vector
            try? modelContext.save()
        }
    }
    
    private func updateCloudEmbedding() async {
        guard let meta = metadata else { return }
        do {
            let vector = try await VertexClient.shared.getEmbedding(videoURL: video.url)
            meta.cloudVisualVector = SemanticSearchManager.shared.normalize(vector)
            try? modelContext.save()
        } catch {
            print("Failed to get cloud embedding: \(error)")
        }
    }
    
    private func analyzeVideo() async {
        isAnalyzing = true
        errorMessage = nil
        
        if video.size > 20_000_000 {
            let msg = "Video is too large (\(video.sizeString)) for direct inline analysis (limit ~20MB). For production, use File API."
            errorMessage = msg
            AppLogger.shared.log(msg, isError: true)
            isAnalyzing = false
            return
        }
        
        AppLogger.shared.log("Starting analysis for \(video.name)")
        
        do {
            let response = try await VertexClient.shared.describeVideo(url: video.url)
            metadata?.summary = response.summary
            metadata?.tags = response.tags
            metadata?.transcript = response.transcript
            metadata?.colorMood = response.colorMood
            metadata?.motionType = response.motionType
            metadata?.contentSafety = response.contentSafety
            metadata?.lastAnalyzedAt = Date()
            
            updateLocalEmbedding()
            try? modelContext.save()
            
            AppLogger.shared.log("Successfully described video.")
            
            await updateCloudEmbedding()
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.shared.log("Analysis failed: \(error.localizedDescription)", isError: true)
        }
        
        isAnalyzing = false
    }
}
