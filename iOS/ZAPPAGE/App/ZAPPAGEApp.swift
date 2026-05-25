import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct ZAPPAGEApp: App {
    @State private var isAuthenticated: Bool

    init() {
        FirebaseApp.configure()
        _isAuthenticated = State(initialValue: Auth.auth().currentUser != nil)
    }

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                HomeView(onSignOut: { isAuthenticated = false })
            } else {
                AuthView {
                    isAuthenticated = true
                }
            }
        }
    }
}
