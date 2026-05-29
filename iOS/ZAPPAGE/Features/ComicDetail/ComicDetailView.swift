import SwiftUI

struct ComicDetailView: View {
    let comic: APIComic
    let backendIP: String
    let tone: ZapTheme.Tone
    @Environment(\.dismiss) private var dismiss

    @State private var detail: ScrapedComicDetail? = nil
    @State private var coverImage: UIImage? = nil
    @State private var isLoadingDetail = true
    @State private var isFavourite = false
    @State private var cbzPages: [CBZPage] = []
    @State private var showReader = false
    @State private var showDeleteConfirm = false
    private let accent = ZapTheme.accent
    private var library: LibraryStore { LibraryStore.shared }
    private var dm: DownloadManager { DownloadManager.shared }
    private var savedComic: LibraryComic? { library.comics.first { $0.sourceURL == comic.url } }
    private var thisDownload: DownloadItem? { dm.downloads[comic.url ?? ""] }

    var body: some View {
        ZStack(alignment: .top) {
            tone.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    contentSection
                    Spacer().frame(height: 48)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Back button pinned over the hero
            backButton
        }
        .fullScreenCover(isPresented: $showReader) {
            CBZReaderView(pages: cbzPages, comicID: savedComic?.id ?? "")
        }
        .alert("Delete this comic?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let saved = savedComic { library.delete(saved) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The CBZ file and cover will be removed from your library.")
        }
        .task {
            async let img   = loadCover()
            async let scrape = loadDetail()
            coverImage = await img
            detail     = await scrape
            isLoadingDetail = false
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        // Total hero height matches JSX (360 + 44 safe-area inset = 404)
        let h: CGFloat = 404
        return ZStack {
            // 1 — Blurred colour backdrop (heavier blur so it reads as abstract colour, not a recognisable image)
            if let img = coverImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .scaleEffect(1.5)
                    .clipped()
                    .opacity(0.9)
            } else {
                LinearGradient(
                    colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            // 2 — Top vignette: darkens the area behind the back button so the blurred colours
            //     don't look raw or washed out. Mirrors the implicit dark top found in the JSX.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0.0),
                    .init(color: .clear,               location: 0.45)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // 3 — Halftone dot grid (JSX: radial-gradient dot overlay, opacity 0.15)
            Canvas { ctx, size in
                let sp: CGFloat = 10, r: CGFloat = 0.7
                for col in 0...Int(size.width / sp) + 1 {
                    for row in 0...Int(size.height / sp) + 1 {
                        ctx.fill(
                            Path(ellipseIn: CGRect(
                                x: CGFloat(col) * sp - r,
                                y: CGFloat(row) * sp - r,
                                width: r * 2, height: r * 2
                            )),
                            with: .color(.white.opacity(0.15))
                        )
                    }
                }
            }

            // 4 — Bottom fade: transparent → tone.bg at 95%, matching JSX exactly.
            //     Starts at centre so the cover art area stays vivid.
            LinearGradient(
                stops: [
                    .init(color: .clear,  location: 0.30),
                    .init(color: tone.bg, location: 0.95)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // 5 — Cover art: 170 × 238, centered vertically in the hero
            VStack(spacing: 0) {
                Spacer()
                Group {
                    if let img = coverImage {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: 188, height: 264)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(tone.chipBg)
                            .frame(width: 188, height: 264)
                            .overlay(ProgressView().tint(accent))
                    }
                }
                .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 12)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: h)
    }

    // MARK: - Back button

    private var backButton: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Spacer()

            if savedComic != nil {
                Button { showDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.48))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .center, spacing: 0) {

            // Publisher badge + meta
            HStack(spacing: 8) {
                if let pub = comic.publisher {
                    publisherBadge(pub)
                }
                let yr = comic.year ?? detail?.year
                let sz = comic.size ?? detail?.size
                let meta = [yr, sz].compactMap { $0 }.joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 11.5))
                        .foregroundStyle(tone.textDim)
                }
            }
            .padding(.bottom, 10)

            // Title
            Text((comic.title ?? detail?.title ?? "—").uppercased())
                .font(ZapTheme.archivoBlack(28))
                .kerning(-0.8)
                .foregroundStyle(tone.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            // Publisher accent sub-label
            if let pub = comic.publisher {
                Text(pub.uppercased())
                    .font(ZapTheme.archivoBlack(13))
                    .kerning(0.5)
                    .foregroundStyle(accent)
                    .padding(.bottom, 18)
            }

            // Download button
            downloadButton
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            // Secondary tiles (Favourite · Library · Share)
            HStack(spacing: 8) {
                ActionTile(
                    icon: isFavourite ? "heart.fill" : "heart",
                    label: isFavourite ? "FAVOURITED" : "FAVOURITE",
                    active: isFavourite, activeColor: Color(hex: "#F04E2A"),
                    tone: tone
                ) { isFavourite.toggle() }

                ActionTile(
                    icon: "bookmark",
                    label: "LIBRARY",
                    active: false, activeColor: accent,
                    tone: tone
                ) { }

                ActionTile(
                    icon: "square.and.arrow.up",
                    label: "SHARE",
                    active: false, activeColor: accent,
                    tone: tone
                ) { }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            // Stat tiles
            statTiles
                .padding(.horizontal, 20)
                .padding(.bottom, 22)

            // Synopsis
            if isLoadingDetail {
                synopsisSkeleton
                    .padding(.horizontal, 20)
            } else if let desc = detail?.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SYNOPSIS")
                        .font(ZapTheme.archivoBlack(11))
                        .kerning(0.8)
                        .foregroundStyle(tone.textMuted)
                    Text(desc)
                        .font(.system(size: 13.5))
                        .lineSpacing(4)
                        .foregroundStyle(tone.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Download button

    private var downloadButton: some View {
        Group {
            if isLoadingDetail {
                RoundedRectangle(cornerRadius: 12).fill(tone.chipBg).frame(height: 52)

            } else if library.isDownloaded(sourceURL: comic.url) {
                Button { openReader() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill").font(.system(size: 14, weight: .bold))
                        Text("READ COMIC").font(ZapTheme.archivoBlack(12)).kerning(0.4)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: accent.opacity(0.45), radius: 14, x: 0, y: 5)
                }.buttonStyle(.plain)

            } else if case .downloading = thisDownload?.status {
                let p = thisDownload?.progress ?? 0
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("DOWNLOADING \(Int(p * 100))%")
                            .font(ZapTheme.archivoBlack(11)).kerning(0.4).foregroundStyle(.white)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.3))
                            RoundedRectangle(cornerRadius: 2).fill(.white)
                                .frame(width: geo.size.width * CGFloat(p))
                                .animation(.easeInOut(duration: 0.3), value: p)
                        }
                    }.frame(height: 3)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .padding(.horizontal, 16)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            } else if case .failed = thisDownload?.status {
                Button { dm.dismiss(sourceURL: comic.url ?? "") } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 14))
                        Text("FAILED — TAP TO DISMISS").font(ZapTheme.archivoBlack(11)).kerning(0.3)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color(hex: "#F04E2A"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

            } else if let d = detail, d.downloadable, d.downloadURL != nil {
                Button { startDownload() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 14, weight: .bold))
                        Text("OFFLINE DOWNLOAD" + (d.size.map { " · \($0)" } ?? ""))
                            .font(ZapTheme.archivoBlack(12)).kerning(0.4)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: accent.opacity(0.45), radius: 14, x: 0, y: 5)
                }.buttonStyle(.plain)

            } else {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle").font(.system(size: 14))
                    Text("NO DOWNLOAD AVAILABLE").font(ZapTheme.archivoBlack(11)).kerning(0.4)
                }
                .foregroundStyle(tone.textMuted)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(tone.chipBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tone.chipBorder, lineWidth: 0.5))
            }
        }
    }

    private func startDownload() {
        guard let d = detail else { return }
        dm.start(comic: comic, detail: d, backendIP: backendIP)
    }

    private func openReader() {
        guard let saved = savedComic else { return }
        let url = LibraryStore.shared.cbzURL(for: saved)
        Task.detached(priority: .userInitiated) {
            guard let pages = try? loadCBZPages(from: url), !pages.isEmpty else { return }
            await MainActor.run { cbzPages = pages; showReader = true }
        }
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: 8) {
            let yr  = comic.year   ?? detail?.year        ?? "—"
            let sz  = comic.size   ?? detail?.size        ?? "—"
            let lng = detail?.language    ?? "—"
            let fmt = detail?.imageFormat ?? "—"
            StatChip(label: "YEAR",     value: yr,  tone: tone)
            StatChip(label: "SIZE",     value: sz,  tone: tone)
            StatChip(label: "LANGUAGE", value: lng, tone: tone)
            StatChip(label: "FORMAT",   value: fmt, tone: tone)
        }
    }

    // MARK: - Synopsis skeleton

    private var synopsisSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(tone.textMuted.opacity(0.4))
                .frame(width: 80, height: 9)
            ForEach([CGFloat(1.0), 0.92, 0.85, 0.6], id: \.self) { w in
                RoundedRectangle(cornerRadius: 3)
                    .fill(tone.textMuted.opacity(0.18))
                    .frame(height: 9)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: w, anchor: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Publisher badge

    private func publisherBadge(_ pub: String) -> some View {
        let (bg, fg) = publisherPalette(pub)
        return HStack(spacing: 5) {
            Circle().fill(fg).frame(width: 5, height: 5)
            Text(pub.uppercased())
                .font(ZapTheme.archivoBlack(10)).kerning(0.8)
                .foregroundStyle(fg)
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func publisherPalette(_ pub: String) -> (Color, Color) {
        switch pub.lowercased() {
        case "marvel":     return (Color(hex: "#E2231A"), .white)
        case "dc":         return (Color(hex: "#0476F2"), .white)
        case "image":      return (.black, .white)
        case "dark horse": return (Color(hex: "#161616"), Color(hex: "#FFE066"))
        default:           return (accent, .white)
        }
    }

    // MARK: - Data loading

    private func loadCover() async -> UIImage? {
        guard let urlStr = comic.coverImage ?? detail?.coverImage,
              let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        return UIImage(data: data)
    }

    private func loadDetail() async -> ScrapedComicDetail? {
        guard let comicURL = comic.url else { return nil }
        return try? await BackendService(ip: backendIP).scrape(comicURL: comicURL)
    }
}

// MARK: - Action tile

private struct ActionTile: View {
    let icon: String
    let label: String
    let active: Bool
    let activeColor: Color
    let tone: ZapTheme.Tone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active ? activeColor.opacity(0.15) : tone.chipBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(active ? activeColor : tone.chipBorder, lineWidth: active ? 1 : 0.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(active ? activeColor : tone.text)
                }
                .frame(height: 48)
                Text(label)
                    .font(ZapTheme.archivoBlack(9))
                    .kerning(0.3)
                    .foregroundStyle(active ? activeColor : tone.textDim)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat chip

private struct StatChip: View {
    let label: String
    let value: String
    let tone: ZapTheme.Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(tone.textMuted)
            Text(value)
                .font(ZapTheme.archivoBlack(13))
                .kerning(-0.2)
                .foregroundStyle(tone.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.chipBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tone.chipBorder, lineWidth: 0.5))
    }
}

#Preview("Dark") {
    ComicDetailView(
        comic: APIComic(title: "Batman · The Dark Knight Returns",
                        publisher: "DC", url: nil, coverImage: nil,
                        year: "2024", size: "32.4 MB", date: nil),
        backendIP: "",
        tone: ZapTheme.dark
    )
    .preferredColorScheme(.dark)
}
