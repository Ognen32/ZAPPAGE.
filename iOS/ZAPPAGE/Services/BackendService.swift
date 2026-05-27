import Foundation

struct BackendService {
    let ip: String
    private var base: String { "http://\(ip.trimmingCharacters(in: .whitespaces))" }

    func search(query: String, page: Int = 1) async throws -> SearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(base)/comics/search?q=\(encoded)&page=\(page)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseSearch(data)
    }

    private func parseSearch(_ data: Data) throws -> SearchResponse {
        let raw = try JSONDecoder().decode(RawSearchResponse.self, from: data)
        let pagination = (raw.pagination ?? [])
            .enumerated()
            .compactMap { APIPaginationItem.from($0.element, index: $0.offset) }
        return SearchResponse(
            page: raw.page,
            query: raw.query,
            noResults: raw.no_results ?? false,
            comics: raw.comics,
            pagination: pagination
        )
    }
}

private struct RawSearchResponse: Decodable {
    let page: Int
    let query: String
    let no_results: Bool?
    let comics: [APIComic]
    let pagination: [RawPaginationItem]?
}
