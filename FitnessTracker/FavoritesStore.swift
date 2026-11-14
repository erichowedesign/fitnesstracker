import Foundation
import Observation

/// Liked Library workout slugs. Survives leaving the screen / relaunch.
@Observable
final class FavoritesStore {
    private(set) var likedSlugs: Set<String> = []
    private let url: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "Foundation", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appending(path: "favorites.json")
        likedSlugs = Self.read(from: url)
    }

    func isLiked(_ slug: String) -> Bool {
        likedSlugs.contains(slug)
    }

    func toggle(_ slug: String) {
        if likedSlugs.contains(slug) {
            likedSlugs.remove(slug)
        } else {
            likedSlugs.insert(slug)
        }
        persist()
    }

    func setLiked(_ slug: String, _ liked: Bool) {
        if liked {
            likedSlugs.insert(slug)
        } else {
            likedSlugs.remove(slug)
        }
        persist()
    }

    private func persist() {
        Self.write(likedSlugs, to: url)
    }

    private static func read(from url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let list = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return Set(list)
    }

    private static func write(_ value: Set<String>, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sorted = value.sorted()
        guard let data = try? encoder.encode(sorted) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
