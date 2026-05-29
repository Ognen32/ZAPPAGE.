import Foundation
import UIKit
import Observation

@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    var comics: [LibraryComic] = []
    var favouriteIDs: Set<String> = []
    var readComicIDs: Set<String> = []
    var readingProgress: [String: LocalReadingProgress] = [:]

    // UID of the currently loaded user — drives UserDefaults key namespacing
    private var currentUID: String?

    // MARK: - Directory layout (Documents/ZAPPAGELibrary/{comics,covers,meta})

    private static var base: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZAPPAGELibrary")
    }
    static var comicsDir: URL { base.appendingPathComponent("comics") }
    static var coversDir: URL { base.appendingPathComponent("covers") }
    private static var metaDir: URL { base.appendingPathComponent("meta") }

    private init() {
        createDirectories()
        load()
        // User-scoped data (favourites, read status, progress) loaded via loadUserData(uid:)
    }

    private func createDirectories() {
        [Self.comicsDir, Self.coversDir, Self.metaDir].forEach {
            try? FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
        }
    }

    // MARK: - User session lifecycle

    /// Call this right after the user signs in (or on HomeView appear).
    func loadUserData(uid: String) {
        currentUID = uid
        favouriteIDs  = Set(UserDefaults.standard.stringArray(forKey: favKey(uid)) ?? [])
        readComicIDs  = Set(UserDefaults.standard.stringArray(forKey: readKey(uid)) ?? [])
        if let data    = UserDefaults.standard.data(forKey: progressKey(uid)),
           let decoded = try? JSONDecoder().decode([String: LocalReadingProgress].self, from: data) {
            readingProgress = decoded
        } else {
            readingProgress = [:]
        }
    }

    /// Call this on sign-out to wipe in-memory user state.
    func clearUserData() {
        currentUID      = nil
        favouriteIDs    = []
        readComicIDs    = []
        readingProgress = [:]
    }

    // MARK: - UserDefaults key helpers

    private func favKey(_ uid: String)      -> String { "favouriteComicIDs_\(uid)" }
    private func readKey(_ uid: String)     -> String { "readComicIDs_\(uid)" }
    private func progressKey(_ uid: String) -> String { "readingProgress_\(uid)" }

    // MARK: - Load / Save / Delete comics

    func load() {
        let fm = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let files = try? fm.contentsOfDirectory(at: Self.metaDir, includingPropertiesForKeys: nil) else { return }
        comics = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(LibraryComic.self, from: Data(contentsOf: $0)) }
            .sorted { $0.downloadedAt > $1.downloadedAt }
    }

    func save(_ comic: LibraryComic) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(comic)
        try data.write(to: Self.metaDir.appendingPathComponent("\(comic.id).json"))
        if !comics.contains(where: { $0.id == comic.id }) {
            comics.insert(comic, at: 0)
        }
    }

    func delete(_ comic: LibraryComic) {
        let fm = FileManager.default
        try? fm.removeItem(at: Self.comicsDir.appendingPathComponent(comic.cbzFilename))
        if let cf = comic.coverFilename {
            try? fm.removeItem(at: Self.coversDir.appendingPathComponent(cf))
        }
        try? fm.removeItem(at: Self.metaDir.appendingPathComponent("\(comic.id).json"))
        comics.removeAll { $0.id == comic.id }
    }

    // MARK: - Favourites

    func toggleFavourite(id: String) {
        if favouriteIDs.contains(id) { favouriteIDs.remove(id) } else { favouriteIDs.insert(id) }
        guard let uid = currentUID else { return }
        UserDefaults.standard.set(Array(favouriteIDs), forKey: favKey(uid))
    }

    func isFavourite(id: String) -> Bool { favouriteIDs.contains(id) }

    // MARK: - Read status

    func toggleRead(id: String) {
        if readComicIDs.contains(id) { readComicIDs.remove(id) } else { readComicIDs.insert(id) }
        guard let uid = currentUID else { return }
        UserDefaults.standard.set(Array(readComicIDs), forKey: readKey(uid))
    }

    func isRead(id: String) -> Bool { readComicIDs.contains(id) }

    // MARK: - Reading progress

    func saveProgress(comicID: String, page: Int, total: Int) {
        readingProgress[comicID] = LocalReadingProgress(page: page, total: total, lastReadAt: Date())
        guard let uid = currentUID else { return }
        if let data = try? JSONEncoder().encode(readingProgress) {
            UserDefaults.standard.set(data, forKey: progressKey(uid))
        }
    }

    // MARK: - Storage size

    var totalSizeBytes: Int64 {
        comics.reduce(0) { total, comic in
            let url = Self.comicsDir.appendingPathComponent(comic.cbzFilename)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }

    var totalSizeFormatted: String {
        let bytes = totalSizeBytes
        if bytes == 0 { return "0 MB" }
        let mb = Double(bytes) / 1_048_576
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        return String(format: "%.2f GB", mb / 1024)
    }

    // MARK: - Accessors

    func cbzURL(for comic: LibraryComic) -> URL {
        Self.comicsDir.appendingPathComponent(comic.cbzFilename)
    }

    func coverImage(for comic: LibraryComic) -> UIImage? {
        guard let cf = comic.coverFilename else { return nil }
        guard let data = try? Data(contentsOf: Self.coversDir.appendingPathComponent(cf)) else { return nil }
        return UIImage(data: data)
    }

    func isDownloaded(sourceURL: String?) -> Bool {
        guard let url = sourceURL, !url.isEmpty else { return false }
        return comics.contains { $0.sourceURL == url }
    }
}
