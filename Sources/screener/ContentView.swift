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
import AVKit
import SwiftData

struct VideoRowView: View {
    let video: VideoFile
    @Query var metadatas: [VideoMetadata]
    let similarityScore: Float?
    
    init(video: VideoFile, similarityScore: Float? = nil) {
        self.video = video
        self.similarityScore = similarityScore
        let path = video.url.path
        _metadatas = Query(filter: #Predicate<VideoMetadata> { $0.filePath == path })
    }
    
    var body: some View {
        HStack {
            if let thumbData = metadatas.first?.thumbnailData, let nsImage = NSImage(data: thumbData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .overlay(Image(systemName: "video").foregroundColor(.gray))
            }
            
            VStack(alignment: .leading) {
                Text(video.name).font(.headline).lineLimit(1)
                
                if let score = similarityScore {
                    Text(String(format: "Score: %.2f", score))
                        .font(.caption)
                        .foregroundColor(score > 0.6 ? .green : .orange)
                }
                
                Text(video.sizeString).font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if metadatas.first?.summary != nil {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.caption)
                }
                if metadatas.first?.cloudVisualVector != nil {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = VideoManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var batchManager = BatchAnalysisManager()
    @ObservedObject private var directoryManager = DirectoryManager.shared
    @Query private var allMetadata: [VideoMetadata]
    
    @State private var selectedVideo: VideoFile?
    @State private var searchText: String = ""
    @State private var isCloudSearching = false
    @State private var showingActivityPopover = false
    @State private var showingLogPopover = false
    
    @State private var searchMode: SearchMode = .cloudVisual
    @State private var cloudQueryVector: [Float]? = nil
    
    enum SearchMode {
        case localText
        case cloudVisual
    }
    
    // Sort videos based on search text
    private var filteredVideos: [(video: VideoFile, score: Float?)] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return manager.videos.map { ($0, nil) }
        }
        
        var scoredVideos: [(video: VideoFile, score: Float)] = []
        
        if searchMode == .localText {
            let queryText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let queryVector = SemanticSearchManager.shared.getLocalTextEmbedding(for: queryText) else {
                return manager.videos.map { ($0, nil) }
            }
            
            for video in manager.videos {
                if let meta = allMetadata.first(where: { $0.filePath == video.url.path }),
                   let videoVector = meta.localTextVector {
                    let score = SemanticSearchManager.shared.cosineSimilarity(a: queryVector, b: videoVector)
                    scoredVideos.append((video, score))
                } else {
                    scoredVideos.append((video, -1.0))
                }
            }
        } else if searchMode == .cloudVisual {
            guard let queryVector = cloudQueryVector else {
                return manager.videos.map { ($0, nil) }
            }
            
            for video in manager.videos {
                if let meta = allMetadata.first(where: { $0.filePath == video.url.path }),
                   let videoVector = meta.cloudVisualVector {
                    let score = SemanticSearchManager.shared.cosineSimilarity(a: queryVector, b: videoVector)
                    scoredVideos.append((video, score))
                } else {
                    scoredVideos.append((video, -1.0))
                }
            }
        }
        
        // Filter out bad matches and sort
        return scoredVideos
            .filter { $0.score > 0.3 }
            .sorted { $0.score > $1.score }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedVideo) {
                let filtered = filteredVideos
                let favorites = filtered.filter { favoritesManager.isFavorite(videoPath: $0.video.url.path) }
                
                if !favorites.isEmpty {
                    Section("Starred") {
                        ForEach(favorites, id: \.video.id) { item in
                            VideoRowView(video: item.video, similarityScore: item.score)
                                .tag(item.video)
                        }
                    }
                }
                
                Section("All Videos") {
                    ForEach(filtered, id: \.video.id) { item in
                        VideoRowView(video: item.video, similarityScore: item.score)
                            .tag(item.video)
                    }
                }
            }
            .navigationTitle("Videos")
            .searchable(text: $searchText, prompt: searchMode == .localText ? "Local Semantic Search..." : "Cloud Visual Search...")
            .onSubmit(of: .search) {
                if searchMode == .cloudVisual {
                    performCloudSearch()
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Search Mode", selection: $searchMode) {
                        Text("Local Text").tag(SearchMode.localText)
                        Text("Cloud Visual").tag(SearchMode.cloudVisual)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: searchMode) { _, _ in
                        cloudQueryVector = nil
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: {
                        showingActivityPopover.toggle()
                    }, label: {
                        Label("Batch Analysis", systemImage: batchManager.isAnalyzing ? "arrow.triangle.2.circlepath.circle.fill" : "cloud.circle")
                            .foregroundColor(batchManager.isAnalyzing ? .blue : .primary)
                    })
                    
                    Button(action: {
                        showingLogPopover.toggle()
                    }, label: {
                        Label("Debug Logs", systemImage: "terminal")
                    })
                    
                    Button(action: {
                        manager.loadVideos(from: directoryManager.directories)
                    }, label: {
                        Label("Refresh Directory", systemImage: "arrow.clockwise")
                    })
                    .keyboardShortcut("r", modifiers: [.command])
                }
            }
            .overlay {
                if manager.videos.isEmpty {
                    ContentUnavailableView("No Videos", systemImage: "video.slash", description: Text("Add a directory containing videos in Settings."))
                } else if filteredVideos.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if isCloudSearching {
                    ProgressView("Generating Cloud Vector...")
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .cornerRadius(8)
                }
            }
        } detail: {
            if let video = selectedVideo {
                DetailView(video: video)
                    .environmentObject(favoritesManager)
            } else {
                ContentUnavailableView("No Video Selected", systemImage: "play.slash", description: Text("Select a video from the sidebar to view its metadata and analysis."))
            }
        }
        .onAppear {
            manager.loadVideos(from: directoryManager.directories)
        }
        .onChange(of: directoryManager.directories) { oldValue, newValue in
            manager.loadVideos(from: newValue)
            selectedVideo = nil
        }
        .sheet(isPresented: $showingActivityPopover) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Batch Analysis")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showingActivityPopover = false
                    }
                }
                
                let analyzedCount = allMetadata.filter { $0.summary != nil && $0.cloudVisualVector != nil }.count
                let totalCount = manager.videos.count
                
                Text("\(analyzedCount) of \(totalCount) videos fully analyzed.")
                    .font(.subheadline)
                
                if batchManager.isAnalyzing {
                    ProgressView(value: Double(batchManager.analyzedVideos), total: Double(batchManager.totalVideos))
                    Text("Processing: \(batchManager.currentVideoName)")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button("Stop Analysis") {
                        batchManager.stopAnalysis()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    if analyzedCount < totalCount {
                        Button("Analyze Missing Videos") {
                            Task {
                                await batchManager.startBatchAnalysis(videos: manager.videos, modelContext: modelContext)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("All videos in library are fully indexed!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .padding()
            .frame(width: 400)
        }
        .sheet(isPresented: $showingLogPopover) {
            VStack(spacing: 0) {
                HStack {
                    Text("Debug Logs")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showingLogPopover = false
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                LogPopoverView()
            }
        }
    }
    
    private func performCloudSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        isCloudSearching = true
        Task {
            do {
                let vector = try await VertexClient.shared.getEmbedding(text: query)
                DispatchQueue.main.async {
                    self.cloudQueryVector = SemanticSearchManager.shared.normalize(vector)
                    self.isCloudSearching = false
                }
            } catch {
                print("Failed to fetch cloud search vector: \(error)")
                DispatchQueue.main.async {
                    self.isCloudSearching = false
                }
            }
        }
    }
}

struct LogPopoverView: View {
    @ObservedObject var logger = AppLogger.shared
    
    var body: some View {
        VStack {
            Text("Debug Logs")
                .font(.headline)
                .padding(.top)
            
            if logger.messages.isEmpty {
                Spacer()
                Text("No logs yet.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(logger.messages) { msg in
                            Text("[\(msg.timestamp.formatted(date: .omitted, time: .standard))] \(msg.text)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(msg.isError ? .red : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
