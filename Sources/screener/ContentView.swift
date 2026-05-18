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
    
    init(video: VideoFile) {
        self.video = video
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
                Text(video.sizeString).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = VideoManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @ObservedObject private var directoryManager = DirectoryManager.shared
    @State private var selectedVideo: VideoFile?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedVideo) {
                let favorites = manager.videos.filter { favoritesManager.isFavorite(videoPath: $0.url.path) }
                if !favorites.isEmpty {
                    Section("Starred") {
                        ForEach(favorites) { video in
                            VideoRowView(video: video)
                                .tag(video)
                        }
                    }
                }
                
                Section("All Videos") {
                    ForEach(manager.videos) { video in
                        VideoRowView(video: video)
                            .tag(video)
                    }
                }
            }
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        manager.loadVideos(from: directoryManager.directories)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            if let video = selectedVideo {
                DetailView(video: video)
                    .environmentObject(favoritesManager)
            } else {
                Text("Select a video to view details")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            manager.loadVideos(from: directoryManager.directories)
        }
        .onChange(of: directoryManager.directories) { oldValue, newValue in
            manager.loadVideos(from: newValue)
            selectedVideo = nil
        }
    }
}
