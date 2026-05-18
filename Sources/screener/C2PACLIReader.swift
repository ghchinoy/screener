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

struct C2PACLIReader {
    static func readFile(at url: URL) throws -> String {
        guard let toolURL = Bundle.module.url(forResource: "c2patool", withExtension: nil) else {
            throw NSError(domain: "C2PA", code: 404, userInfo: [NSLocalizedDescriptionKey: "c2patool binary not found in bundle"])
        }
        
        let task = Process()
        task.executableURL = toolURL
        task.arguments = [url.path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            if jsonString.isEmpty {
                 throw NSError(domain: "C2PA", code: 404, userInfo: [NSLocalizedDescriptionKey: "No C2PA manifest found"])
            }
            return jsonString
        } else {
            throw NSError(domain: "C2PA", code: 404, userInfo: [NSLocalizedDescriptionKey: "No C2PA manifest found"])
        }
    }
}
