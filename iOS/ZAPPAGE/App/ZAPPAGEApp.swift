import SwiftUI

@main
struct ZAPPAGEApp: App {
    @State private var isAuthenticated = false

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                HomeView()
            } else {
                AuthView {
                    isAuthenticated = true
                }
            }
        }
    }
}
