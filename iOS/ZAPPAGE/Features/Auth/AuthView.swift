import SwiftUI

struct AuthView: View {
    @State private var vm = AuthViewModel()
    @AppStorage("zapLanguage") private var languageRaw: String = ZapLanguage.english.rawValue
    @Environment(\.colorScheme) private var scheme

    var onAuthenticated: (() -> Void)?

    private var tone: ZapTheme.Tone  { scheme == .dark ? ZapTheme.dark : ZapTheme.light }
    private let accent: Color = ZapTheme.accent
    private var language: ZapLanguage { ZapLanguage(rawValue: languageRaw) ?? .english }
    private var s: ZapStrings { ZapStrings(language: language) }

    var body: some View {
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
        PrimaryButton(label: vm.tab == .login ? s.logIn : s.createAccount, accent: accent) {
            vm.submitEmail(strings: s)
            if vm.errorMessage == nil { onAuthenticated?() }
        }
        .padding(.top, 16)
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
            SocialButton(icon: AnyView(AppleSignInIcon(color: tone.text)), label: "Apple", tone: tone) {
                vm.signInWithApple(); onAuthenticated?()
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

#Preview("Dark") { AuthView().preferredColorScheme(.dark) }
#Preview("Light") { AuthView().preferredColorScheme(.light) }
