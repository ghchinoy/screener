import SwiftUI
import SwiftData

@MainActor
class BatchAnalysisManager: ObservableObject {
    @Published var isAnalyzing = false
    @Published var totalVideos = 0
    @Published var analyzedVideos = 0
    @Published var currentVideoName: String = ""
    
    func startBatchAnalysis(videos: [VideoFile], modelContext: ModelContext) async {
        isAnalyzing = true
        
        let descriptor = FetchDescriptor<VideoMetadata>()
        let allMetadata = (try? modelContext.fetch(descriptor)) ?? []
        
        var missingVideos: [VideoFile] = []
        for video in videos {
            if let meta = allMetadata.first(where: { $0.filePath == video.url.path }) {
                if meta.summary == nil || meta.cloudVisualVector == nil {
                    missingVideos.append(video)
                }
            } else {
                missingVideos.append(video)
            }
        }
        
        totalVideos = missingVideos.count
        analyzedVideos = 0
        
        for video in missingVideos {
            guard isAnalyzing else { break }
            currentVideoName = video.name
            
            let path = video.url.path
            let meta: VideoMetadata
            if let existing = allMetadata.first(where: { $0.filePath == path }) {
                meta = existing
            } else {
                meta = VideoMetadata(filePath: path)
                modelContext.insert(meta)
            }
            
            // Only describe if missing
            if meta.summary == nil {
                do {
                    // Check size
                    if video.size <= 20_000_000 {
                        let response = try await VertexClient.shared.describeVideo(url: video.url)
                        meta.summary = response.summary
                        meta.tags = response.tags
                        meta.transcript = response.transcript
                        meta.colorMood = response.colorMood
                        meta.motionType = response.motionType
                        meta.contentSafety = response.contentSafety
                        
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
                        }
                    }
                } catch {
                    print("Failed to describe \(video.name): \(error)")
                }
            }
            
            // Only fetch visual vector if missing
            if meta.cloudVisualVector == nil {
                do {
                    let vector = try await VertexClient.shared.getEmbedding(videoURL: video.url)
                    meta.cloudVisualVector = SemanticSearchManager.shared.normalize(vector)
                } catch {
                    print("Failed to get cloud embedding for \(video.name): \(error)")
                }
            }
            
            try? modelContext.save()
            analyzedVideos += 1
        }
        
        isAnalyzing = false
        currentVideoName = ""
    }
    
    func stopAnalysis() {
        isAnalyzing = false
    }
}
