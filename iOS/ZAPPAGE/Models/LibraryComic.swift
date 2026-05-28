import Foundation

struct LibraryComic: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let publisher: String?
    let year: String?
    let size: String?
    let language: String?
    let imageFormat: String?
    let sourceURL: String?
    let downloadedAt: Date
    let cbzFilename: String
    let coverFilename: String?
}
