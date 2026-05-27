import Foundation

struct APIComic: Identifiable, Decodable {
    var id = UUID()
    let title: String?
    let publisher: String?
    let url: String?
    let coverImage: String?
    let year: String?
    let size: String?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case title, publisher, url, year, size, date
        case coverImage = "cover_image"
    }
}

enum APIPaginationItem: Identifiable {
    case page(number: Int, url: String)
    case current(number: Int)
    case dots(index: Int)

    var id: String {
        switch self {
        case .page(let n, _):  return "p_\(n)"
        case .current(let n):  return "c_\(n)"
        case .dots(let i):     return "d_\(i)"
        }
    }

    var number: Int? {
        switch self {
        case .page(let n, _):  return n
        case .current(let n):  return n
        case .dots:            return nil
        }
    }

    static func from(_ raw: RawPaginationItem, index: Int) -> APIPaginationItem? {
        switch raw.type {
        case "page":
            guard let n = raw.number, let u = raw.url else { return nil }
            return .page(number: n, url: u)
        case "current":
            guard let n = raw.number else { return nil }
            return .current(number: n)
        case "dots":
            return .dots(index: index)
        default:
            return nil
        }
    }
}

struct RawPaginationItem: Decodable {
    let type: String
    let number: Int?
    let url: String?
}

struct SearchResponse {
    let page: Int
    let query: String
    let noResults: Bool
    let comics: [APIComic]
    let pagination: [APIPaginationItem]
}
