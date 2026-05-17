import Foundation

class DirectoryManager: ObservableObject {
    static let shared = DirectoryManager()
    
    @Published var directories: [String] = []
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "savedDirectories"),
           let decoded = try? JSONDecoder().decode([String].self, from: data), !decoded.isEmpty {
            self.directories = decoded
        } else {
            // Default directory if none exist
            self.directories = ["~/Movies"]
        }
    }
    
    func addDirectory(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !directories.contains(trimmed) {
            directories.append(trimmed)
            save()
        }
    }
    
    func removeDirectory(at offsets: IndexSet) {
        directories.remove(atOffsets: offsets)
        save()
    }
    
    func removeDirectory(_ path: String) {
        if let index = directories.firstIndex(of: path) {
            directories.remove(at: index)
            save()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(directories) {
            UserDefaults.standard.set(data, forKey: "savedDirectories")
        }
    }
}

class FavoritesManager: ObservableObject {
    @Published var favoritePaths: Set<String> = []
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "favoriteVideos"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.favoritePaths = decoded
        }
    }
    
    func toggle(videoPath: String) {
        if favoritePaths.contains(videoPath) {
            favoritePaths.remove(videoPath)
        } else {
            favoritePaths.insert(videoPath)
        }
        save()
    }
    
    func isFavorite(videoPath: String) -> Bool {
        return favoritePaths.contains(videoPath)
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(favoritePaths) {
            UserDefaults.standard.set(data, forKey: "favoriteVideos")
        }
    }
}
