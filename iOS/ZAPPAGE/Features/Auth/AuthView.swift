import SwiftUI

struct AuthView: View {
    @State private var vm = AuthViewModel()
    @State private var showSuccess = false
    @AppStorage("zapLanguage") private var languageRaw: String = ZapLanguage.english.rawValue
    @Environment(\.colorScheme) private var scheme

    var onAuthenticated: (() -> Void)?

    private var tone: ZapTheme.Tone  { scheme == .dark ? ZapTheme.dark : ZapTheme.light }
    private let accent: Color = ZapTheme.accent
    private var language: ZapLanguage { ZapLanguage(rawValue: languageRaw) ?? .english }
    private var s: ZapStrings { ZapStrings(language: language) }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    brandBar
                    heroCard
                    welcomeBlock
                    tabToggle
                    formFields
                    ctaButton
                    divider
                    socialRow
                    termsText
                    guestButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(tone.bg.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .blur(radius: showSuccess ? 8 : 0)

            if showSuccess {
                AuthSuccessOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSuccess)
    }

    // MARK: - Brand bar + language toggle
    private var brandBar: some View {
        HStack {
            ZapWordmark(size: 20, textColor: tone.text, accent: accent)
            Spacer()
            LanguageToggle(selected: $languageRaw, tone: tone, accent: accent)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Hero illustration
    private var heroCard: some View {
        HeroIllustration(accent: accent, hero: .zap, isDark: scheme == .dark)
    }

    // MARK: - Welcome heading
    private var welcomeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if vm.tab == .login {
                    (Text(s.welcomeMain).font(ZapTheme.archivoBlack(28))
                        + Text(s.welcomeAccent).font(ZapTheme.archivoBlack(28)).foregroundStyle(accent)
                        + Text(".").font(ZapTheme.archivoBlack(28)))
                } else {
                    (Text(s.joinThe).font(ZapTheme.archivoBlack(28))
                        + Text(s.joinAccent).font(ZapTheme.archivoBlack(28)).foregroundStyle(accent)
                        + Text(".").font(ZapTheme.archivoBlack(28)))
                }
            }
            .foregroundStyle(tone.text)
            .kerning(-0.6)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(vm.tab == .login ? s.loginSubtitle : s.signupSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(tone.textDim)
                .kerning(-0.1)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 22)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: language)
    }

    // MARK: - Tab toggle
    private var tabToggle: some View {
        AuthTabToggle(selection: $vm.tab, loginLabel: s.logIn, signupLabel: s.signUp,
                      accent: accent, tone: tone)
    }

    // MARK: - Form fields
    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 10) {
            if vm.tab == .signup {
                ZapTextField(icon: "person",
                             placeholder: s.usernamePlaceholder,
                             text: $vm.username,
                             tone: tone, accent: accent)
                .transition(.opacity.combined(with: .move(edge: .top)))

                HeroPickerRow(selected: $vm.selectedHero, label: s.chooseYourHero, tone: tone, accent: accent)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ZapTextField(icon: "envelope",
                         placeholder: s.emailPlaceholder,
                         text: $vm.email,
                         tone: tone, accent: accent)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)

            ZapTextField(icon: "lock",
                         placeholder: s.passwordPlaceholder,
                         text: $vm.password,
                         isSecure: !vm.showPassword,
                         tone: tone, accent: accent) {
                Button { vm.showPassword.toggle() } label: {
                    Image(systemName: vm.showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundStyle(tone.textDim)
                }
            }

            if vm.tab == .login {
                HStack {
                    Spacer()
                    Button(s.forgotPassword) { /* TODO */ }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(accent)
                        .kerning(-0.1)
                }
                .padding(.top, 2)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: "#E63946"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 16)
        .animation(.easeInOut(duration: 0.2), value: vm.tab)
    }

    // MARK: - Primary CTA
    private var ctaButton: some View {
        Group {
            if vm.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                    Text(vm.tab == .login ? "Signing in…" : "Creating account…")
                        .font(ZapTheme.archivoBlack(13))
                        .kerning(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(accent.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                PrimaryButton(label: vm.tab == .login ? s.logIn : s.createAccount, accent: accent) {
                    vm.submitEmail(strings: s) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            showSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            onAuthenticated?()
                        }
                    }
                }
            }
        }
        .padding(.top, 16)
        .animation(.easeInOut(duration: 0.18), value: vm.isLoading)
    }

    // MARK: - OR divider
    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().frame(height: 0.5).foregroundStyle(tone.line)
            Text(s.orContinueWith)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone.textMuted)
                .kerning(0.8)
                .textCase(.uppercase)
                .fixedSize()
            Rectangle().frame(height: 0.5).foregroundStyle(tone.line)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Social buttons
    private var socialRow: some View {
        HStack(spacing: 10) {
            SocialButton(icon: AnyView(FacebookSignInIcon()), label: "Facebook", tone: tone) {
                vm.signInWithFacebook(); onAuthenticated?()
            }
            SocialButton(icon: AnyView(GoogleSignInIcon()), label: "Google", tone: tone) {
                vm.signInWithGoogle(); onAuthenticated?()
            }
        }
    }

    // MARK: - Terms
    private var termsText: some View {
        (Text(s.termsPrefix).foregroundStyle(tone.textMuted)
            + Text(s.terms).foregroundStyle(tone.textDim).fontWeight(.semibold)
            + Text(s.termsAnd).foregroundStyle(tone.textMuted)
            + Text(s.privacyPolicy).foregroundStyle(tone.textDim).fontWeight(.semibold)
            + Text(s.termsSuffix).foregroundStyle(tone.textMuted))
        .font(.system(size: 11))
        .kerning(-0.05)
        .multilineTextAlignment(.center)
        .padding(.top, 18)
    }

    // MARK: - Guest link
    private var guestButton: some View {
        Button {
            vm.continueAsGuest(); onAuthenticated?()
        } label: {
            Text(s.continueAsGuest)
                .font(ZapTheme.archivoBlack(11))
                .kerning(1)
                .textCase(.uppercase)
                .foregroundStyle(tone.textDim)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }
}

// MARK: - Language toggle (EN | МК pill)
private struct LanguageToggle: View {
    @Binding var selected: String
    let tone: ZapTheme.Tone
    let accent: Color
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ZapLanguage.allCases, id: \.self) { lang in
                ZStack {
                    if selected == lang.rawValue {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accent)
                            .matchedGeometryEffect(id: "langPill", in: ns)
                    }
                    Text(lang.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selected == lang.rawValue ? .white : tone.textDim)
                        .animation(.easeInOut(duration: 0.16), value: selected)
                }
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.22, dampingFraction: 1.0)) {
                        selected = lang.rawValue
                    }
                }
            }
        }
        .padding(2)
        .background(tone.chipBg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
    }
}

// MARK: - Tab toggle
private struct AuthTabToggle: View {
    @Binding var selection: AuthTab
    let loginLabel: String
    let signupLabel: String
    let accent: Color
    let tone: ZapTheme.Tone
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases) { tab in
                ZStack {
                    if selection == tab {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accent)
                            .shadow(color: accent.opacity(0.33), radius: 4, x: 0, y: 2)
                            .matchedGeometryEffect(id: "pill", in: ns)
                    }
                    Text(tab == .login ? loginLabel : signupLabel)
                        .font(ZapTheme.archivoBlack(12))
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(selection == tab ? .white : tone.textDim)
                        .animation(.easeInOut(duration: 0.16), value: selection)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.22, dampingFraction: 1.0)) { selection = tab }
                }
            }
        }
        .padding(3)
        .frame(height: 40)
        .background(tone.chipBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tone.chipBorder, lineWidth: 0.5))
    }
}

// MARK: - Hero picker
private struct HeroPickerRow: View {
    @Binding var selected: ZapTheme.HeroKind
    let label: String
    let tone: ZapTheme.Tone
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(ZapTheme.archivoBlack(11))
                .kerning(0.8)
                .foregroundStyle(tone.textDim)

            HStack(spacing: 8) {
                ForEach(ZapTheme.HeroKind.allCases, id: \.self) { hero in
                    HeroOption(hero: hero, selected: $selected, accent: accent)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct HeroOption: View {
    let hero: ZapTheme.HeroKind
    @Binding var selected: ZapTheme.HeroKind
    let accent: Color

    private var isSelected: Bool { hero == selected }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { selected = hero }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(colors: [hero.bgFrom, hero.bgTo],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HeroCardParticles(hero: hero)
                    ChibiHero(kind: hero, accent: accent, size: 58)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? accent : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 0.5)
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .shadow(color: isSelected ? accent.opacity(0.45) : .black.opacity(0.35),
                        radius: isSelected ? 10 : 4, x: 0, y: 4)

                VStack(spacing: 1) {
                    Text(hero.displayName)
                        .font(ZapTheme.archivoBlack(10))
                        .kerning(0.5)
                        .foregroundStyle(isSelected ? accent : Color(hex: "#FAFAFA").opacity(0.5))

                    Text(hero.roleLabel)
                        .font(.system(size: 8, weight: .medium))
                        .kerning(0.3)
                        .foregroundStyle(isSelected ? accent.opacity(0.7) : Color(hex: "#FAFAFA").opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hero card particle overlays (live-animated via TimelineView)
private struct HeroCardParticles: View {
    let hero: ZapTheme.HeroKind

    // Each hero gets a vivid, on-theme particle colour visible on dark backgrounds
    private var pc: Color {
        switch hero {
        case .zap:   return Color(hex: "#FFD84D")  // electric gold
        case .bolt:  return Color(hex: "#7EC0FF")  // arc blue
        case .nyx:   return Color(hex: "#C9A8FF")  // mystic lavender
        case .ember: return Color(hex: "#FF7B3A")  // fire orange
        }
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                switch hero {
                case .zap:   drawLightning(ctx, size, t)
                case .bolt:  drawSparks(ctx, size, t)
                case .nyx:   drawStarbursts(ctx, size, t)
                case .ember: drawFlames(ctx, size, t)
                }
            }
        }
    }

    // ZAP — large flickering lightning bolts, each strobes independently
    private func drawLightning(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let spots: [(CGFloat, CGFloat)] = [(0.12, 0.12), (0.80, 0.08), (0.88, 0.58), (0.20, 0.75), (0.52, 0.28)]
        for (i, (rx, ry)) in spots.enumerated() {
            let fi  = Double(i)
            let raw = sin(t * (3.8 + fi * 0.9) + fi * 2.1)
            let opacity = raw > 0.15 ? min(0.95, 0.9 * raw) : 0
            guard opacity > 0 else { continue }
            let x = rx * size.width, y = ry * size.height
            var bolt = Path()
            bolt.move(to:    CGPoint(x: x + 3,   y: y))
            bolt.addLine(to: CGPoint(x: x - 1.5, y: y + 4))
            bolt.addLine(to: CGPoint(x: x + 1.5, y: y + 4))
            bolt.addLine(to: CGPoint(x: x - 3,   y: y + 9))
            ctx.stroke(bolt, with: .color(pc.opacity(opacity)),
                       style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    // BOLT — pulsing 8-ray spark bursts, clearly visible
    private func drawSparks(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.14, 5.5), (0.83, 0.11, 5.0), (0.76, 0.70, 6.0), (0.20, 0.76, 4.5), (0.50, 0.38, 5.0)]
        for (i, (rx, ry, baseLen)) in spots.enumerated() {
            let fi      = Double(i)
            let pulse   = 0.65 + 0.35 * sin(t * (2.2 + fi * 0.5) + fi * 1.7)
            let opacity = max(0, 0.5 + 0.35 * sin(t * (1.5 + fi * 0.4) + fi * 0.9))
            let len     = baseLen * CGFloat(pulse)
            let x = rx * size.width, y = ry * size.height
            // centre dot
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)),
                     with: .color(pc.opacity(opacity)))
            for j in 0..<8 {
                let angle = CGFloat(j) * .pi / 4
                var ray = Path()
                ray.move(to:    CGPoint(x: x + cos(angle) * 1.8, y: y + sin(angle) * 1.8))
                ray.addLine(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len))
                ctx.stroke(ray, with: .color(pc.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }

    // NYX — twinkling 4-point crosshair stars, highly visible
    private func drawStarbursts(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.10, 0.11, 4.5), (0.86, 0.13, 3.5), (0.78, 0.68, 4.5), (0.18, 0.76, 4.0), (0.48, 0.33, 3.0), (0.63, 0.19, 3.0)]
        for (i, (rx, ry, baseR)) in spots.enumerated() {
            let fi      = Double(i)
            let twinkle = 0.5 * (1 + sin(t * (1.2 + fi * 0.35) + fi * 2.5))
            let r       = baseR * CGFloat(0.35 + 0.65 * twinkle)
            let opacity = 0.25 + 0.55 * twinkle
            let x = rx * size.width, y = ry * size.height
            // long arms
            var star = Path()
            star.move(to: CGPoint(x: x,       y: y - r));     star.addLine(to: CGPoint(x: x,       y: y + r))
            star.move(to: CGPoint(x: x - r,   y: y));         star.addLine(to: CGPoint(x: x + r,   y: y))
            // short diagonal arms
            let d = r * 0.52
            star.move(to: CGPoint(x: x - d, y: y - d)); star.addLine(to: CGPoint(x: x + d, y: y + d))
            star.move(to: CGPoint(x: x + d, y: y - d)); star.addLine(to: CGPoint(x: x - d, y: y + d))
            ctx.stroke(star, with: .color(pc.opacity(opacity)),
                       style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            // bright centre dot
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                     with: .color(pc.opacity(min(1, opacity * 1.4))))
        }
    }

    // EMBER — real fire: wide flat base, sides curve inward, narrow pointed tip; rises & sways
    private func drawFlames(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        // (baseX ratio, speed, radius, phase offset)
        let defs: [(CGFloat, Double, CGFloat, Double)] = [
            (0.18, 0.36, 3.8, 0.00),
            (0.50, 0.42, 3.0, 0.28),
            (0.78, 0.32, 4.2, 0.58),
            (0.33, 0.39, 3.4, 0.78),
            (0.64, 0.35, 2.8, 0.13),
        ]
        for (bx, speed, r, phOff) in defs {
            let phase = (t * speed + phOff).truncatingRemainder(dividingBy: 1.0)
            // Rise from 88 % → 8 % of card height
            let cy    = size.height * CGFloat(0.88 - 0.80 * phase)
            // Wind sway — tip leans more than base
            let sway  = size.width * 0.045 * CGFloat(sin(t * 1.8 + phOff * 5.1))
            let baseX = bx * size.width             // base stays put
            let tipX  = baseX + sway                // tip drifts with wind

            let opacity: Double = phase < 0.12 ? phase / 0.12 * 0.80
                                : phase > 0.72 ? (1 - (phase - 0.72) / 0.28) * 0.80
                                : 0.80

            // Fire shape: wide flat base at BOTTOM, sides curve INWARD going up, pointed TIP at TOP
            //   tip  ← narrow
            //  /   \
            // |     |  ← sides bow outward slightly in the lower third
            // |_____|  ← wide flat base
            let halfBase = r * 1.3
            let baseY    = cy + r * 0.6    // flat base at bottom
            let tipY     = cy - r * 2.4   // pointed tip at top

            var flame = Path()
            // start at left base corner
            flame.move(to: CGPoint(x: baseX - halfBase, y: baseY))
            // flat base to right corner
            flame.addLine(to: CGPoint(x: baseX + halfBase, y: baseY))
            // right side: curves inward as it rises to tip
            flame.addCurve(
                to:       CGPoint(x: tipX, y: tipY),
                control1: CGPoint(x: baseX + halfBase * 1.1, y: cy + r * 0.0),
                control2: CGPoint(x: tipX + r * 0.35,        y: tipY + r * 1.0))
            // left side: symmetric, from tip back down to left base
            flame.addCurve(
                to:       CGPoint(x: baseX - halfBase, y: baseY),
                control1: CGPoint(x: tipX - r * 0.35,        y: tipY + r * 1.0),
                control2: CGPoint(x: baseX - halfBase * 1.1, y: cy + r * 0.0))

            ctx.fill(flame, with: .color(pc.opacity(opacity)))

            // bright inner core — smaller, same shape, higher opacity
            let ir = r * 0.55
            let iHalf = ir * 1.1
            var core = Path()
            core.move(to: CGPoint(x: baseX - iHalf, y: baseY))
            core.addLine(to: CGPoint(x: baseX + iHalf, y: baseY))
            core.addCurve(
                to:       CGPoint(x: tipX, y: tipY + r * 0.9),
                control1: CGPoint(x: baseX + iHalf * 1.1, y: cy + ir * 0.0),
                control2: CGPoint(x: tipX + ir * 0.3,     y: tipY + r * 1.1))
            core.addCurve(
                to:       CGPoint(x: baseX - iHalf, y: baseY),
                control1: CGPoint(x: tipX - ir * 0.3,     y: tipY + r * 1.1),
                control2: CGPoint(x: baseX - iHalf * 1.1, y: cy + ir * 0.0))
            ctx.fill(core, with: .color(pc.opacity(min(1, opacity * 1.25))))
        }
    }
}

// MARK: - Success overlay (bubble expand from center)
private struct AuthSuccessOverlay: View {
    private let accent = ZapTheme.accent
    @State private var bubbleScale:     CGFloat = 0.01
    @State private var textScale:       CGFloat = 0.6
    @State private var textOpacity:     Double  = 0
    @State private var subtitleOffset:  CGFloat = 22
    @State private var subtitleOpacity: Double  = 0

    var body: some View {
        ZStack {
            // Orange bubble that expands from center dot to fill screen
            Circle()
                .fill(accent)
                .frame(width: 1200, height: 1200)
                .scaleEffect(bubbleScale)

            VStack(spacing: 14) {
                Text("ZAP!")
                    .font(ZapTheme.archivoBlack(96))
                    .kerning(-3)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 4, y: 4)
                    .scaleEffect(textScale)
                    .opacity(textOpacity)

                Text("YOU'RE IN")
                    .font(ZapTheme.archivoBlack(20))
                    .kerning(3)
                    .foregroundStyle(.white.opacity(0.88))
                    .offset(y: subtitleOffset)
                    .opacity(subtitleOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.76)) {
                bubbleScale = 1.0
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65).delay(0.28)) {
                textScale   = 1.0
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.32).delay(0.44)) {
                subtitleOffset  = 0
                subtitleOpacity = 1
            }
        }
    }
}

#Preview("Dark") { AuthView().preferredColorScheme(.dark) }
#Preview("Light") { AuthView().preferredColorScheme(.light) }
