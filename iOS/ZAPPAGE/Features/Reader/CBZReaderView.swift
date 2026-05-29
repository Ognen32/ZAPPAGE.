import SwiftUI

enum ComicReadingMode: String, CaseIterable {
    case single   = "Single Page"
    case spread   = "Two Pages"
    case vertical = "Vertical"

    var icon: String {
        switch self {
        case .single:   return "rectangle.portrait"
        case .spread:   return "rectangle.split.2x1"
        case .vertical: return "arrow.down.to.line"
        }
    }
    var hint: String {
        switch self {
        case .single:   return "Swipe left & right"
        case .spread:   return "Pinch to zoom · drag to pan"
        case .vertical: return "Scroll top to bottom"
        }
    }
}

struct CBZReaderView: View {
    let pages: [CBZPage]
    let comicID: String
    private let spreadPairs: [[CBZPage]]

    @State private var currentPage  = 0
    @State private var showHUD      = true
    @State private var showPanel    = false
    @State private var mode: ComicReadingMode = .single
    @State private var spreadZoomed = false
    @Environment(\.dismiss) private var dismiss
    private let accent = ZapTheme.accent

    init(pages: [CBZPage], comicID: String) {
        self.pages  = pages
        self.comicID = comicID
        var pairs: [[CBZPage]] = []
        var i = 0
        while i < pages.count {
            pairs.append(i + 1 < pages.count ? [pages[i], pages[i + 1]] : [pages[i]])
            i += 2
        }
        self.spreadPairs = pairs
        let saved = LibraryStore.shared.readingProgress[comicID]
        _currentPage = State(initialValue: saved?.page ?? 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch mode {
            case .single:   singleReader
            case .spread:   spreadReader
            case .vertical: verticalReader
            }

            if showHUD   { hud.transition(.opacity) }
            if showPanel { panelOverlay.transition(.opacity) }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.22), value: showHUD)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showPanel)
        .animation(.easeInOut(duration: 0.18), value: spreadZoomed)
        .onChange(of: mode) { _, _ in spreadZoomed = false }
        .onDisappear {
            LibraryStore.shared.saveProgress(comicID: comicID, page: currentPage, total: pages.count)
        }
    }

    // MARK: - Single page
    private var singleReader: some View {
        TabView(selection: $currentPage) {
            ForEach(pages) { page in
                CBZPageImage(data: page.imageData)
                    .allowsHitTesting(false)
                    .tag(page.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .simultaneousGesture(TapGesture().onEnded { toggleHUD() })
    }

    // MARK: - Spread
    private var currentSpreadPair: [CBZPage] {
        let idx = currentPage / 2
        return idx < spreadPairs.count ? spreadPairs[idx] : []
    }

    @ViewBuilder
    private var spreadReader: some View {
        if spreadZoomed {
            ZoomableSpreadPage(pair: currentSpreadPair, onTap: toggleHUD, isZoomed: $spreadZoomed)
                .ignoresSafeArea()
        } else {
            let spreadIndex = Binding<Int>(
                get: { currentPage / 2 },
                set: { currentPage = $0 * 2 }
            )
            TabView(selection: spreadIndex) {
                ForEach(Array(spreadPairs.enumerated()), id: \.offset) { idx, pair in
                    EntrySpreadPage(pair: pair, onTap: toggleHUD) {
                        spreadZoomed = true
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }

    // MARK: - Vertical scroll
    private var verticalReader: some View {
        let screen = UIScreen.main.bounds
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                    CBZPageImage(data: page.imageData)
                        .frame(maxWidth: screen.width, maxHeight: screen.height)
                        .allowsHitTesting(false)
                        .onAppear { currentPage = idx }
                }
            }
        }
        .ignoresSafeArea()
        .simultaneousGesture(TapGesture().onEnded { toggleHUD() })
    }

    // MARK: - HUD
    private var hud: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                        Text("Back").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                if mode == .spread && spreadZoomed {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { spreadZoomed = false }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "minus.magnifyingglass").font(.system(size: 12, weight: .bold))
                            Text("Zoom Out").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Color(hex: "#2a2a3c"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { showPanel.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("\(currentPage + 1) / \(pages.count)")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 14)
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.12)).frame(width: 26, height: 22)
                            Image(systemName: showPanel ? "xmark" : "slider.horizontal.3")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                        }
                    }
                    .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 9)
                    .background(.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(showPanel ? accent.opacity(0.4) : .white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 16)

            Spacer()

            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: pages.isEmpty ? 0 : max(8, geo.size.width * CGFloat(currentPage + 1) / CGFloat(pages.count)))
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 3)

                HStack {
                    Label(mode.rawValue, systemImage: mode.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .labelStyle(.titleAndIcon)
                    Spacer()
                    let left = pages.count - currentPage - 1
                    Text(left > 0 ? "\(left) left" : "Last page")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 36)
        }
    }

    // MARK: - Settings panel
    private var panelOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { showPanel = false }
                }
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.25))
                    .frame(width: 40, height: 4).padding(.top, 14).padding(.bottom, 22)
                HStack {
                    Text("READING MODE").font(ZapTheme.archivoBlack(10)).kerning(1.2).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
                HStack(spacing: 10) {
                    ForEach(ComicReadingMode.allCases, id: \.rawValue) { m in
                        ModeCard(mode: m, selected: mode == m, accent: accent) {
                            withAnimation(.easeOut(duration: 0.22)) { mode = m; currentPage = 0 }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: "#16161f"))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
            )
        }
    }

    private func toggleHUD() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showHUD.toggle()
            if !showHUD { showPanel = false }
        }
    }
}

// MARK: - Async image tile
private struct CBZPageImage: View {
    let data: Data
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(hex: "#0d0d14")
            }
        }
        .task {
            guard image == nil else { return }
            let d = data
            image = await Task.detached(priority: .userInitiated) { UIImage(data: d) }.value
        }
    }
}

// MARK: - Entry spread page (inside TabView — no DragGesture to avoid swipe conflict)
private struct EntrySpreadPage: View {
    let pair: [CBZPage]
    let onTap: () -> Void
    let onZoomEntry: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 1) {
                ForEach(pair) { page in
                    CBZPageImage(data: page.imageData)
                        .frame(maxWidth: .infinity)
                }
            }
            .allowsHitTesting(false)

            Color.clear.contentShape(Rectangle())
                .gesture(MagnificationGesture().onChanged { if $0 > 1.04 { onZoomEntry() } })
                .simultaneousGesture(TapGesture().onEnded { onTap() })
        }
    }
}

// MARK: - Zoomable spread page (standalone — DragGesture has no TabView to fight with)
// Uses @State + lastOffset instead of @GestureState so there is no reset-snap at drag end.
private struct ZoomableSpreadPage: View {
    let pair: [CBZPage]
    let onTap: () -> Void
    @Binding var isZoomed: Bool

    @State private var scale:      CGFloat = 1
    @State private var lastScale:  CGFloat = 1
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    var body: some View {
        HStack(spacing: 1) {
            ForEach(pair) { page in
                CBZPageImage(data: page.imageData).frame(maxWidth: .infinity)
            }
        }
        // Rasterise to a Metal texture once; scale + offset become GPU-only ops per frame.
        .drawingGroup()
        .scaleEffect(scale, anchor: .center)
        .offset(x: offset.width, y: offset.height)
        // Pinch
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1, lastScale * value)
                }
                .onEnded { value in
                    let final = max(1, lastScale * value)
                    lastScale = final
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        scale = final
                    }
                    if final <= 1.02 {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                        }
                        isZoomed = false
                    }
                }
        )
        // Drag — instant follow-finger, no animation; commits on end.
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    guard scale > 1.05 else { return }
                    offset = CGSize(
                        width:  lastOffset.width  + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    guard scale > 1.05 else { return }
                    lastOffset = offset
                }
        )
        // Double-tap zoom toggle
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                if scale > 1.1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero; isZoomed = false }
                else            { scale = 2.5; lastScale = 2.5 }
            }
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - Mode card
private struct ModeCard: View {
    let mode: ComicReadingMode; let selected: Bool; let accent: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? accent.opacity(0.15) : .white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? accent : .white.opacity(0.1), lineWidth: selected ? 1.5 : 0.5))
                    Image(systemName: mode.icon).font(.system(size: 22, weight: .light))
                        .foregroundStyle(selected ? accent : .white.opacity(0.5))
                }
                .frame(height: 64)
                VStack(spacing: 4) {
                    Text(mode.rawValue).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? accent : .white.opacity(0.65))
                    Text(mode.hint).font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain).frame(maxWidth: .infinity).padding(.bottom, 4)
    }
}
