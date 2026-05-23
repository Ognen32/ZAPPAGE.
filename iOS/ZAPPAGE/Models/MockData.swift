import Foundation

struct MockComic: Identifiable {
    let id = UUID()
    let title: String       // may contain \n for line breaks
    let issue: String
    let sub: String
    let publisher: String
    let pages: Int
    let rating: Double
    let year: Int
    let palette: [String]   // [bgFrom, bgTo, fg, fgAlt]
    var progress: Double = 0
    var currentPage: Int = 0
    var isDownloaded: Bool = false
    var isFavourite: Bool = false
    var fileSizeMB: Double = 0

    var displayTitle: String { title.replacingOccurrences(of: "\n", with: " ") }
    var bgFrom:  String { palette[0] }
    var bgTo:    String { palette[1] }
    var fg:      String { palette[2] }
    var fgAlt:   String { palette[3] }
}

enum MockData {
    static let covers: [MockComic] = [
        MockComic(title: "NIGHT\nVECTOR",  issue: "#42", sub: "Vol. 3 · The Wake",   publisher: "Image",      pages: 32, rating: 4.7, year: 2026, palette: ["#0a1e3a","#3a0a5e","#ffd84d","#ff7b9c"], progress: 0.56, currentPage: 18, isDownloaded: true,  fileSizeMB: 24.5),
        MockComic(title: "IRON\nMERIDIAN", issue: "#07", sub: "Origin Cycle",         publisher: "Marvel",     pages: 28, rating: 4.5, year: 2026, palette: ["#7a1414","#1a0606","#ffb84d","#ffe9c2"], progress: 0.78, currentPage: 22, isDownloaded: true,  fileSizeMB: 31.2),
        MockComic(title: "SOLAR\nSAINTS",  issue: "#15", sub: "Crown of Embers",      publisher: "Marvel",     pages: 36, rating: 4.8, year: 2025, palette: ["#ff6b1a","#a31b00","#fff4d6","#ffd17a"], progress: 0.15, currentPage: 5,  isDownloaded: true,  fileSizeMB: 18.9),
        MockComic(title: "HOLLOW\nKING",   issue: "#01", sub: "Debut Issue",          publisher: "DC",         pages: 40, rating: 4.6, year: 2026, palette: ["#0b3a2e","#021310","#9bffd5","#3effb0"], progress: 0.91, currentPage: 36, isDownloaded: false, fileSizeMB: 0),
        MockComic(title: "BLACK\nMERCURY", issue: "#23", sub: "Quiet War",            publisher: "DC",         pages: 32, rating: 4.4, year: 2025, palette: ["#1a1a2e","#0a0a14","#c9c9ff","#7a7aff"], progress: 0.42, currentPage: 13, isDownloaded: true,  fileSizeMB: 27.0),
        MockComic(title: "KID\nVANTA",     issue: "#04", sub: "School Arc",           publisher: "Boom!",      pages: 24, rating: 4.9, year: 2026, palette: ["#ff3b8a","#54155f","#ffffff","#ffe1f0"], progress: 0,    currentPage: 0,  isDownloaded: false, isFavourite: true,  fileSizeMB: 0),
        MockComic(title: "GRAVE\nORACLE",  issue: "#11", sub: "Tides Below",          publisher: "Dark Horse", pages: 28, rating: 4.3, year: 2025, palette: ["#003a4a","#001a24","#7ee7ff","#2ec2e5"], progress: 0,    currentPage: 0,  isDownloaded: false, fileSizeMB: 0),
        MockComic(title: "ATLAS\nUNBOUND", issue: "#88", sub: "Final Page",           publisher: "Marvel",     pages: 48, rating: 4.7, year: 2026, palette: ["#3a2510","#0f0a05","#ffd28a","#ff9a3c"], progress: 0,    currentPage: 0,  isDownloaded: true,  fileSizeMB: 22.6),
        MockComic(title: "NEON\nFRIARS",   issue: "#02", sub: "Issue Two",            publisher: "Image",      pages: 32, rating: 4.2, year: 2026, palette: ["#7a00a3","#1e0033","#ff5edb","#ffb1f0"], progress: 0,    currentPage: 0,  isDownloaded: false, fileSizeMB: 0),
        MockComic(title: "SILVER\nFAULT",  issue: "#19", sub: "Aftershock",           publisher: "IDW",        pages: 28, rating: 4.5, year: 2025, palette: ["#2b2b2b","#0a0a0a","#e8e8e8","#a0a0a0"], progress: 1.0,  currentPage: 28, isDownloaded: false, fileSizeMB: 0),
        MockComic(title: "BLUE\nCARDINAL", issue: "#06", sub: "Migration",            publisher: "DC",         pages: 32, rating: 4.6, year: 2026, palette: ["#0a4a8a","#02132a","#ffd84d","#7ec0ff"], progress: 0.22, currentPage: 7,  isDownloaded: false, fileSizeMB: 0),
        MockComic(title: "RED\nKNOLL",     issue: "#34", sub: "Mountain Arc",         publisher: "Marvel",     pages: 36, rating: 4.5, year: 2026, palette: ["#a31b00","#3a0a05","#ffffff","#ffb88a"], progress: 0,    currentPage: 0,  isDownloaded: true,  fileSizeMB: 18.0),
    ]

    static var continueReading: [MockComic] { [covers[0], covers[4], covers[8], covers[10], covers[6], covers[1]] }
    static var newThisWeek:     [MockComic] { [covers[2], covers[5], covers[3], covers[11], covers[9], covers[1]] }
    static var myLibrary:       [MockComic] { [covers[1], covers[7], covers[11], covers[4], covers[2]] }
    static var trending:        [MockComic] { [covers[5], covers[2], covers[0], covers[3], covers[8]] }
    static var featured:         MockComic  { covers[0] }
}
