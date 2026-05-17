import Foundation
import SwiftData

@Model
class VideoMetadata {
    @Attribute(.unique) var filePath: String
    
    // User comments
    var comments: String = ""
    
    // Core Technical Metadata
    var duration: Double?
    var width: Double?
    var height: Double?
    var frameRate: Float?
    var hasAudio: Bool?
    
    // Visual Artifacts
    @Attribute(.externalStorage) var thumbnailData: Data?
    
    // C2PA Metadata
    var hasC2PA: Bool?
    var c2paIssuer: String?
    var c2paTool: String?
    @Attribute(.externalStorage) var c2paManifestJSON: String?
    
    // Advanced AI / Gemini Analyses
    var summary: String?
    var tags: [String] = []
    var transcript: String?
    var colorMood: String?
    var motionType: String?
    var contentSafety: String?
    
    init(filePath: String) {
        self.filePath = filePath
    }
}
