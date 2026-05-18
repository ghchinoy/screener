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
