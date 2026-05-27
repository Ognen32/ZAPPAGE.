import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FacebookCore

@main
struct ZAPPAGEApp: App {
    @State private var isAuthenticated: Bool

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        _isAuthenticated = State(initialValue: Auth.auth().currentUser != nil)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    HomeView(onSignOut: { isAuthenticated = false })
                } else {
                    AuthView { isAuthenticated = true }
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
                ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:])
            }
        }
    }
}
