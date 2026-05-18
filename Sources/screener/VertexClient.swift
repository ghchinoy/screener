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

enum VertexError: Error, LocalizedError {
    case missingCredentials
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Missing GCP Project ID or Access Token. Check Settings (Cmd+,) or run 'gcloud auth application-default login'."
        case .invalidResponse: return "Invalid response from Vertex AI."
        case .apiError(let msg): return "API Error: \(msg)"
        }
    }
}

struct GeminiResponse: Codable {
    let summary: String
    let tags: [String]
    let transcript: String?
    let colorMood: String?
    let motionType: String?
    let contentSafety: String?
}

struct VertexRawResponsePart: Decodable {
    let text: String?
}

struct VertexRawResponseContent: Decodable {
    let parts: [VertexRawResponsePart]?
}

struct VertexRawResponseCandidate: Decodable {
    let content: VertexRawResponseContent?
}

struct VertexRawResponse: Decodable {
    let candidates: [VertexRawResponseCandidate]?
}

class VertexClient {
    static let shared = VertexClient()
    private init() {}
    
    private var modelName: String {
        UserDefaults.standard.string(forKey: "modelName") ?? "gemini-3.1-flash-lite"
    }
    
    private var configuredProject: String {
        UserDefaults.standard.string(forKey: "gcpProject") ?? ""
    }
    
    private var configuredLocation: String {
        UserDefaults.standard.string(forKey: "gcpLocation") ?? "global"
    }
    
    private var configuredEnvironment: String {
        UserDefaults.standard.string(forKey: "environment") ?? "prod"
    }
    
    func describeVideo(url: URL) async throws -> GeminiResponse {
        let token = try fetchADCToken()
        let projectID = configuredProject.isEmpty ? try fetchProjectID() : configuredProject
        let location = configuredLocation.isEmpty ? "global" : configuredLocation
        let safeModelName = modelName.isEmpty ? "gemini-3.1-flash-lite" : modelName
        
        let baseHost: String
        switch configuredEnvironment {
        case "autopush": baseHost = "autopush-aiplatform.sandbox.googleapis.com"
        case "staging": baseHost = "staging-aiplatform.sandbox.googleapis.com"
        default: baseHost = "aiplatform.googleapis.com"
        }
        
        let host = location == "global" ? baseHost : "\(location)-\(baseHost)"
        let endpoint = "https://\(host)/v1/projects/\(projectID)/locations/\(location)/publishers/google/models/\(safeModelName):generateContent"
        
        guard let apiURL = URL(string: endpoint) else {
            throw VertexError.apiError("Invalid URL")
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
        
        let fileData = try Data(contentsOf: url)
        let base64String = fileData.base64EncodedString()
        let mimeType = url.pathExtension.lowercased() == "mov" ? "video/mp4" : "video/mp4"
        
        let prompt = """
        Analyze this video and output a JSON object containing exactly these keys:
        - "summary": A concise 2-3 sentence description of what happens in the video.
        - "tags": An array of up to 5 short string tags.
        - "transcript": Audio transcription (if speech is present), otherwise "No speech".
        - "colorMood": A short description of the dominant colors and visual mood.
        - "motionType": A short description of the camera action/motion type (e.g., Static, Fast pan, Drone).
        - "contentSafety": A brief assessment of content safety (e.g., "Safe", "Contains violence").
        Respond ONLY with valid JSON.
        """
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": mimeType,
                                "data": base64String
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VertexError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            throw VertexError.apiError("Status \(httpResponse.statusCode): \(errorMsg)")
        }
        
        let rawResponse = try JSONDecoder().decode(VertexRawResponse.self, from: data)
        guard let text = rawResponse.candidates?.first?.content?.parts?.first?.text else {
            throw VertexError.invalidResponse
        }
        
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                              .replacingOccurrences(of: "```json", with: "")
                              .replacingOccurrences(of: "```", with: "")
                              .trimmingCharacters(in: .whitespacesAndNewlines)
                              
        guard let textData = cleanedText.data(using: .utf8) else {
            throw VertexError.invalidResponse
        }
        
        return try JSONDecoder().decode(GeminiResponse.self, from: textData)
    }
    
    private func fetchADCToken() throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/google-cloud-sdk/bin; gcloud auth application-default print-access-token"
        task.arguments = ["-c", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else { throw VertexError.missingCredentials }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else { throw VertexError.missingCredentials }
        return token
    }
    
    private func fetchProjectID() throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        let script = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/google-cloud-sdk/bin; gcloud config get-value project"
        task.arguments = ["-c", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else { throw VertexError.missingCredentials }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let project = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !project.isEmpty else { throw VertexError.missingCredentials }
        return project
    }
}
