import Foundation

struct CBZPage: Identifiable {
    let id: Int
    let imageData: Data
}

func loadCBZPages(from url: URL) throws -> [CBZPage] {
    let needsStop = url.startAccessingSecurityScopedResource()
    defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

    let bytes = try Data(contentsOf: url)
    let n = bytes.count

    func byte(_ i: Int) -> Int { i < n ? Int(bytes[i]) : 0 }
    func u16(_ i: Int) -> Int  { byte(i) | byte(i+1) << 8 }
    func u32(_ i: Int) -> Int  { byte(i) | byte(i+1) << 8 | byte(i+2) << 16 | byte(i+3) << 24 }
    func sig(_ i: Int) -> UInt32 {
        guard i + 3 < n else { return 0 }
        return UInt32(bytes[i]) | UInt32(bytes[i+1]) << 8 | UInt32(bytes[i+2]) << 16 | UInt32(bytes[i+3]) << 24
    }

    guard n >= 22,
          let eocd = (max(0, n - 65558)...(n - 22)).reversed()
              .first(where: { sig($0) == 0x06054b50 })
    else { throw NSError(domain: "CBZ", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a valid CBZ/ZIP file"]) }

    let totalEntries = u16(eocd + 10)
    var cdOff = u32(eocd + 16)
    var entries: [(name: String, data: Data)] = []

    for _ in 0..<totalEntries {
        guard cdOff + 46 <= n, sig(cdOff) == 0x02014b50 else { break }

        let method     = u16(cdOff + 10)
        let compSz     = u32(cdOff + 20)
        let uncompSz   = u32(cdOff + 24)
        let nameLen    = u16(cdOff + 28)
        let extraLen   = u16(cdOff + 30)
        let commentLen = u16(cdOff + 32)
        let localOff   = u32(cdOff + 42)

        let nameEnd = cdOff + 46 + nameLen
        guard nameEnd <= n else { break }
        let name = String(data: bytes[(cdOff + 46)..<nameEnd], encoding: .utf8) ?? ""
        let ext  = (name as NSString).pathExtension.lowercased()

        if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext), compSz > 0 {
            let lnl       = u16(localOff + 26)
            let lel       = u16(localOff + 28)
            let dataStart = localOff + 30 + lnl + lel
            let dataEnd   = dataStart + compSz

            if dataEnd <= n {
                let compressed = Data(bytes[dataStart..<dataEnd])
                let imgData: Data?
                switch method {
                case 0:  imgData = compressed
                case 8:  imgData = inflateRaw(compressed, expectedSize: uncompSz)
                default: imgData = nil
                }
                if let d = imgData { entries.append((name: name, data: d)) }
            }
        }
        cdOff += 46 + nameLen + extraLen + commentLen
    }

    entries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    return entries.enumerated().map { CBZPage(id: $0, imageData: $1.data) }
}

private func inflateRaw(_ data: Data, expectedSize: Int) -> Data? {
    if let result = try? (data as NSData).decompressed(using: .zlib) as Data { return result }
    var wrapped = Data([0x78, 0x9C])
    wrapped.append(data)
    wrapped.append(contentsOf: [0, 0, 0, 1])
    return try? (wrapped as NSData).decompressed(using: .zlib) as Data
}
