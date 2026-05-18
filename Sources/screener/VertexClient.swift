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

struct EmbeddingResponse: Codable {
    struct Prediction: Codable {
        let embeddings: EmbeddingValues?
        let textEmbedding: [Float]? // Sometimes returned differently based on model version
    }
    struct EmbeddingValues: Codable {
        let values: [Float]
    }
    let predictions: [Prediction]?
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
    
    func getEmbedding(text: String? = nil, videoURL: URL? = nil) async throws -> [Float] {
        let token = try fetchADCToken()
        let projectID = configuredProject.isEmpty ? try fetchProjectID() : configuredProject
        let location = configuredLocation.isEmpty ? "us-central1" : configuredLocation
        
        let baseHost: String
        switch configuredEnvironment {
        case "autopush": baseHost = "autopush-aiplatform.sandbox.googleapis.com"
        case "staging": baseHost = "staging-aiplatform.sandbox.googleapis.com"
        default: baseHost = "aiplatform.googleapis.com"
        }
        
        let host = location == "global" ? baseHost : "\(location)-\(baseHost)"
        
        let embeddingModel = "multimodalembedding@001" 
        let endpoint = "https://\(host)/v1/projects/\(projectID)/locations/\(location)/publishers/google/models/\(embeddingModel):predict"
        
        await MainActor.run { AppLogger.shared.log("Requesting embedding from \(host) using \(embeddingModel)...") }
        
        guard let apiURL = URL(string: endpoint) else {
            throw VertexError.apiError("Invalid URL")
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(projectID, forHTTPHeaderField: "x-goog-user-project")
        
        var instance: [String: Any] = [:]
        if let text = text {
            instance["text"] = text
        }
        if let videoURL = videoURL {
            let fileData = try Data(contentsOf: videoURL)
            let base64String = fileData.base64EncodedString()
            await MainActor.run { AppLogger.shared.log("Encoding video of size \(fileData.count) bytes") }
            instance["video"] = [
                "bytesBase64Encoded": base64String
            ]
        }
        
        let payload: [String: Any] = [
            "instances": [instance]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            await MainActor.run { AppLogger.shared.log("Invalid HTTP Response from Vertex", isError: true) }
            throw VertexError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown API Error"
            await MainActor.run { AppLogger.shared.log("Embedding Error \(httpResponse.statusCode): \(errorMsg)", isError: true) }
            throw VertexError.apiError("Status \(httpResponse.statusCode): \(errorMsg)")
        }
        
        let rawResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        if let first = rawResponse.predictions?.first {
            if let values = first.embeddings?.values {
                await MainActor.run { AppLogger.shared.log("Successfully retrieved embedding (\(values.count) dimensions)") }
                return values
            } else if let values = first.textEmbedding {
                await MainActor.run { AppLogger.shared.log("Successfully retrieved text embedding (\(values.count) dimensions)") }
                return values
            }
        }
        
        await MainActor.run { AppLogger.shared.log("Response did not contain valid embedding data", isError: true) }
        throw VertexError.invalidResponse
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
