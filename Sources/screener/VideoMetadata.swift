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

typealias VideoMetadata = VideoSchemaV2.VideoMetadata

extension VideoMetadata {
    var localTextVector: [Float]? {
        get {
            guard let data = localTextVectorData else { return nil }
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        set {
            if let newValue = newValue {
                localTextVectorData = newValue.withUnsafeBufferPointer { Data(buffer: $0) }
            } else {
                localTextVectorData = nil
            }
        }
    }
    
    var cloudVisualVector: [Float]? {
        get {
            guard let data = cloudVisualVectorData else { return nil }
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        set {
            if let newValue = newValue {
                cloudVisualVectorData = newValue.withUnsafeBufferPointer { Data(buffer: $0) }
            } else {
                cloudVisualVectorData = nil
            }
        }
    }
}
