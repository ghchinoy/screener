import Foundation

struct VideoFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let creationDate: Date
    let size: Int64
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

class VideoManager: ObservableObject {
    @Published var videos: [VideoFile] = []
    
    func loadVideos(from paths: [String]) {
        let fileManager = FileManager.default
        var loadedVideos: [VideoFile] = []
        
        for path in paths {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
                continue
            }
            
            for case let fileURL as URL in enumerator {
                let pathExtension = fileURL.pathExtension.lowercased()
                if ["mp4", "mov", "m4v"].contains(pathExtension) {
                    do {
                        let resources = try fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                        let creationDate = resources.creationDate ?? Date()
                        let size = Int64(resources.fileSize ?? 0)
                        
                        let video = VideoFile(url: fileURL, name: fileURL.lastPathComponent, creationDate: creationDate, size: size)
                        loadedVideos.append(video)
                    } catch {
                        print("Error reading properties for \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.videos = loadedVideos.sorted { $0.creationDate > $1.creationDate }
        }
    }
}
