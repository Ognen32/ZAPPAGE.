import SwiftUI
import Observation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import FacebookLogin

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
                    UserSession.cacheHero(self.selectedHero, uid: result.user.uid)
                    try await Firestore.firestore()
                        .collection("users")
                        .document(result.user.uid)
                        .setData([
                            "uid":       result.user.uid,
                            "username":  self.username,
                            "email":     self.email,
                            "hero":      self.selectedHero.rawValue,
                            "createdAt": FieldValue.serverTimestamp()
                        ])
                }
                onSuccess()
            } catch let err as NSError {
                errorMessage = friendlyError(err)
            }
            isLoading = false
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(onSuccess: @escaping () -> Void, onNeedsProfile: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Google sign-in failed. Please try again."
                    isLoading = false
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                let authResult = try await Auth.auth().signIn(with: credential)

                // Block Google login if the account was created with email/password
                if authResult.user.providerData.contains(where: { $0.providerID == "password" }) {
                    try? Auth.auth().signOut()
                    errorMessage = "This email already has an account. Please log in with your email and password."
                    isLoading = false
                    return
                }

                // Check Firestore to distinguish returning Google user vs truly new user
                let uid = authResult.user.uid
                let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
                if doc.exists {
                    isLoading = false
                    onSuccess()
                } else {
                    email    = authResult.user.email ?? ""
                    username = result.user.profile?.givenName ?? authResult.user.displayName ?? ""
                    isLoading = false
                    onNeedsProfile()
                }
            } catch let err as NSError {
                isLoading = false
                if err.code != 1 { // 1 = user cancelled the Google sheet
                    errorMessage = "Google sign-in failed. Please try again."
                }
            }
        }
    }

    func completeGoogleProfile(onSuccess: @escaping () -> Void) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Username is required."
            return
        }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                guard let user = Auth.auth().currentUser else { return }
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = username
                try await changeRequest.commitChanges()
                UserSession.cacheHero(selectedHero, uid: user.uid)
                try await Firestore.firestore()
                    .collection("users")
                    .document(user.uid)
                    .setData([
                        "uid":       user.uid,
                        "username":  username,
                        "email":     user.email ?? email,
                        "hero":      selectedHero.rawValue,
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                isLoading = false
                onSuccess()
            } catch let err as NSError {
                errorMessage = friendlyError(err)
                isLoading = false
            }
        }
    }

    // MARK: - Facebook Sign-In

    func signInWithFacebook(onSuccess: @escaping () -> Void, onNeedsProfile: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        isLoading = true
        errorMessage = nil

        let loginManager = LoginManager()
        loginManager.logIn(permissions: ["public_profile", "email"], from: rootVC) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.errorMessage = "Facebook sign-in failed. Please try again."
                    self.isLoading = false
                    return
                }
                guard let result, !result.isCancelled,
                      let tokenString = result.token?.tokenString else {
                    self.isLoading = false
                    return
                }
                do {
                    let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
                    let authResult  = try await Auth.auth().signIn(with: credential)

                    // Block if account was created with email/password
                    if authResult.user.providerData.contains(where: { $0.providerID == "password" }) {
                        try? Auth.auth().signOut()
                        self.errorMessage = "This email already has an account. Please log in with your email and password."
                        self.isLoading = false
                        return
                    }

                    let uid = authResult.user.uid
                    let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
                    if doc.exists {
                        self.isLoading = false
                        onSuccess()
                    } else {
                        self.email    = authResult.user.email ?? ""
                        self.username = authResult.user.displayName ?? ""
                        self.isLoading = false
                        onNeedsProfile()
                    }
                } catch let err as NSError {
                    self.errorMessage = self.friendlyError(err)
                    self.isLoading = false
                }
            }
        }
    }
    func continueAsGuest()    { /* TODO: Firebase anonymous auth */ }

    // MARK: - Private

    private func friendlyError(_ error: NSError) -> String {
        switch error.code {
        case 17004, 17009: return "Wrong password. If you signed up with Google, use the Google button."
        case 17005:        return "This account has been disabled."
        case 17007:        return "An account with this email already exists."
        case 17012:        return "This email is linked to a different sign-in method. Try logging in another way."
        case 17008:        return "Please enter a valid email address."
        case 17011:        return "No password account found. Try signing in with Google."
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
