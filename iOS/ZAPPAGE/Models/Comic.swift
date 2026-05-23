import Foundation

struct Comic: Identifiable, Codable {
    let id: String
    var title: String
    var issue: String
    var subtitle: String
    var publisher: String
    var pages: Int
    var rating: Double
    var year: Int
    var paletteFrom: String      // hex
    var paletteTo: String        // hex
    var paletteFg: String        // hex
    var paletteFgAlt: String     // hex
    var isDownloaded: Bool
    var isFavourite: Bool
    var readingProgress: Double  // 0.0 – 1.0
}

struct ReadingProgress: Identifiable, Codable {
    let id: String
    let userId: String
    let comicId: String
    var currentPage: Int
    var totalPages: Int
    var lastReadAt: Date

    var fraction: Double { totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0 }
}
