import SwiftUI
import Observation
import FirebaseAuth

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

    // MARK: - Email auth

    func submitEmail(strings: ZapStrings, onSuccess: @escaping () -> Void) {
        guard validate(strings: strings) else { return }
        isLoading = true
        Task { @MainActor in
            do {
                if tab == .login {
                    try await Auth.auth().signIn(withEmail: email, password: password)
                } else {
                    let result = try await Auth.auth().createUser(withEmail: email, password: password)
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = self.username
                    try await changeRequest.commitChanges()
                }
                onSuccess()
            } catch let err as NSError {
                errorMessage = friendlyError(err)
            }
            isLoading = false
        }
    }

    func signInWithFacebook() { /* TODO: LoginManager → Firebase */ }
    func signInWithGoogle()   { /* TODO: GIDSignIn → Firebase */ }
    func continueAsGuest()    { /* TODO: Firebase anonymous auth */ }

    // MARK: - Private

    private func friendlyError(_ error: NSError) -> String {
        switch error.code {
        case 17004, 17009: return "Wrong password. Please try again."
        case 17005:        return "This account has been disabled."
        case 17007:        return "An account with this email already exists."
        case 17008:        return "Please enter a valid email address."
        case 17011:        return "No account found with this email."
        case 17026:        return "Password must be at least 6 characters."
        case 17020:        return "No internet connection. Check your network."
        case 17010:        return "Too many attempts. Try again later."
        default:           return "Something went wrong. Please try again."
        }
    }

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
