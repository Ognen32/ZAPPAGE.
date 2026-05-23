import SwiftUI
import Observation

enum AuthTab: String, CaseIterable, Identifiable {
    case login  = "login"
    case signup = "signup"
    var id: String { rawValue }
}

@Observable
final class AuthViewModel {
    var tab: AuthTab = .login
    var email: String = ""
    var password: String = ""
    var username: String = ""
    var selectedHero: ZapTheme.HeroKind = .zap
    var showPassword: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // MARK: - Auth actions (wired to Firebase in a later sprint)

    func submitEmail(strings: ZapStrings) {
        guard validate(strings: strings) else { return }
        isLoading = true
        Task {
            // TODO: FirebaseAuthService.shared.signIn / signUp
            isLoading = false
        }
    }

    func signInWithApple()    { /* TODO: ASAuthorizationAppleIDProvider → Firebase */ }
    func signInWithFacebook() { /* TODO: LoginManager → Firebase */ }
    func signInWithGoogle()   { /* TODO: GIDSignIn → Firebase */ }
    func continueAsGuest()  { /* TODO: Firebase anonymous auth */ }

    // MARK: - Private

    private func validate(strings: ZapStrings) -> Bool {
        errorMessage = nil
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = strings.errorEmailRequired; return false
        }
        if password.count < 6 {
            errorMessage = strings.errorPasswordShort; return false
        }
        if tab == .signup && username.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = strings.errorUsernameRequired; return false
        }
        return true
    }
}
