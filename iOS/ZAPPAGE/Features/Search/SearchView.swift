import SwiftUI

struct SearchView: View {
    let tone: ZapTheme.Tone
    let s: ZapStrings
    let backendIP: String
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var results: [APIComic] = []
    @State private var pagination: [APIPaginationItem] = []
    @State private var isLoading = false
    @State private var noResults = false
    @State private var currentPage = 1
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    private let accent = ZapTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().overlay(tone.line)

            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if noResults {
                    noResultsView
                } else if results.isEmpty && !query.isEmpty {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        resultGrid
                        if !pagination.isEmpty {
                            paginationBar
                        }
                        Spacer().frame(height: 32)
                    }
                }
            }
        }
        .background(tone.bg.ignoresSafeArea())
        .onAppear { focused = true }
    }

    // MARK: - Search bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tone.text)
                    .frame(width: 36, height: 36)
                    .background(tone.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(tone.chipBorder, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(focused ? tone.text : tone.textDim)
                TextField(s.searchPlaceholder, text: $query)
                    .font(.system(size: 15))
                    .foregroundStyle(tone.text)
                    .tint(accent)
                    .focused($focused)
                    .submitLabel(.search)
                    .onChange(of: query) { _, new in triggerSearch(query: new, page: 1) }
                    .onSubmit { triggerSearch(query: query, page: currentPage, debounce: false) }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(tone.textDim)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(focused ? tone.fieldFocus : tone.field)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent.opacity(0.5) : tone.chipBorder, lineWidth: 0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(tone.bg)
    }

    // MARK: - Results grid
    private var resultGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(results) { comic in
                SearchResultCard(comic: comic, tone: tone, accent: accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Pagination
    private var paginationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(pagination) { item in
                    switch item {
                    case .page(let n, _):
                        Button {
                            triggerSearch(query: query, page: n, debounce: false)
                        } label: {
                            pageChip(label: "\(n)", active: false)
                        }
                        .buttonStyle(.plain)
                    case .current(let n):
                        pageChip(label: "\(n)", active: true)
                    case .dots:
                        Text("…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(tone.textMuted)
                            .frame(width: 28, height: 32)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private func pageChip(label: String, active: Bool) -> some View {
        Text(label)
            .font(ZapTheme.archivoBlack(12))
            .kerning(0.2)
            .foregroundStyle(active ? .white : tone.text)
            .frame(minWidth: 32, minHeight: 32)
            .padding(.horizontal, 6)
            .background(active ? accent : tone.chipBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? accent : tone.chipBorder, lineWidth: 0.5))
    }

    // MARK: - Empty / no results
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(tone.textMuted)
            Text(s.searchPlaceholder)
                .font(.system(size: 14))
                .foregroundStyle(tone.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(tone.textMuted)
            Text(s.noResults)
                .font(ZapTheme.archivoBlack(16))
                .foregroundStyle(tone.text)
                .textCase(.uppercase)
            Text(s.noResultsSub)
                .font(.system(size: 13))
                .foregroundStyle(tone.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
    }

    // MARK: - Search logic
    private func triggerSearch(query: String, page: Int, debounce: Bool = true) {
        searchTask?.cancel()
        currentPage = page
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []; pagination = []; noResults = false; isLoading = false; return
        }
        isLoading = true
        searchTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
            }
            do {
                let response = try await BackendService(ip: backendIP).search(query: query, page: page)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = response.comics
                    pagination = response.pagination
                    noResults = response.noResults
                    currentPage = response.page
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Search result card
private struct SearchResultCard: View {
    let comic: APIComic
    let tone: ZapTheme.Tone
    let accent: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottom) {
            coverImage

            // dark strip — top-left aligned, no blur, height follows content
            VStack(alignment: .leading, spacing: 4) {
                if let pub = comic.publisher {
                    Text(pub.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .kerning(0.5)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
                Text(comic.title ?? "—")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase)
                    .kerning(-0.1)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .background(
                scheme == .dark
                    ? Color(hex: "#0d0d14").opacity(0.95)
                    : Color(hex: "#1a2040").opacity(0.93)
            )

            // size chip — top right, bigger
            if let size = comic.size {
                VStack {
                    HStack {
                        Spacer()
                        Text(size)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
    }

    private var coverImage: some View {
        Group {
            if let urlString = comic.coverImage, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "book.closed")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.12))
        )
    }
}
