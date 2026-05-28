import Foundation
import UIKit

struct DownloadService {
    let backendIP: String
    private var base: String { "http://\(backendIP.trimmingCharacters(in: .whitespaces))" }

    func download(
        comic: APIComic,
        detail: ScrapedComicDetail,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> LibraryComic {
        guard let downloadURL = detail.downloadURL else { throw DownloadError.noURL }

        let store = LibraryStore.shared
        let id    = UUID().uuidString

        // '+' and '=' are base64 chars in these URLs — must be percent-encoded or FastAPI misparses them
        var safeChars = CharacterSet.urlQueryAllowed
        safeChars.remove(charactersIn: "+=")
        let encoded = downloadURL.addingPercentEncoding(withAllowedCharacters: safeChars) ?? downloadURL
        guard let url = URL(string: "\(base)/comic/download?url=\(encoded)") else {
            throw DownloadError.badURL
        }

        onProgress(0.02)

        // Stream bytes so we can report real progress using Content-Length
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        guard let http = response as? HTTPURLResponse else { throw DownloadError.serverError }

        switch http.statusCode {
        case 200:  break
        case 415:  throw DownloadError.unsupportedFormat
        default:   throw DownloadError.serverError
        }

        let totalBytes  = Double(http.expectedContentLength)   // -1 when unknown
        let serverName  = http.value(forHTTPHeaderField: "X-Comic-Filename") ?? "comic.cbz"

        // Write streamed bytes to a temp file, flushing every 64 KB
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(id).tmp.cbz")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tmpURL)

        var received: Int64 = 0
        var buffer = Data(capacity: 65_536)

        do {
            for try await byte in asyncBytes {
                buffer.append(byte)
                received += 1
                if buffer.count >= 65_536 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    if totalBytes > 0 {
                        // Scale byte progress to 0.02 – 0.72 (cover + metadata get the rest)
                        onProgress(min(0.02 + 0.70 * Double(received) / totalBytes, 0.72))
                    }
                }
            }
            if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
            try handle.close()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: tmpURL)
            throw error
        }

        onProgress(0.74)

        // Move to permanent library storage
        let cbzFilename = "\(id)_\(serverName)"
        let cbzDest     = LibraryStore.comicsDir.appendingPathComponent(cbzFilename)
        try FileManager.default.moveItem(at: tmpURL, to: cbzDest)

        onProgress(0.80)

        // Download + save cover image
        var coverFilename: String?
        let coverURLStr = comic.coverImage ?? detail.coverImage
        if let urlStr = coverURLStr,
           let coverURL = URL(string: urlStr),
           let (coverData, _) = try? await URLSession.shared.data(from: coverURL),
           UIImage(data: coverData) != nil {
            let cf = "\(id).jpg"
            try? coverData.write(to: LibraryStore.coversDir.appendingPathComponent(cf))
            coverFilename = cf
        }

        onProgress(0.94)

        // Persist metadata
        let libraryComic = LibraryComic(
            id:            id,
            title:         comic.title ?? detail.title ?? "Unknown",
            publisher:     comic.publisher,
            year:          comic.year ?? detail.year,
            size:          comic.size ?? detail.size,
            language:      detail.language,
            imageFormat:   detail.imageFormat,
            sourceURL:     comic.url,
            downloadedAt:  Date(),
            cbzFilename:   cbzFilename,
            coverFilename: coverFilename
        )
        try store.save(libraryComic)
        onProgress(1.0)

        return libraryComic
    }
}

enum DownloadError: LocalizedError {
    case noURL, badURL, serverError, unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .noURL:             return "No download URL available for this comic."
        case .badURL:            return "Invalid backend URL."
        case .serverError:       return "Server error — please try again."
        case .unsupportedFormat: return "Unsupported format — only CBZ files are supported."
        }
    }
}
