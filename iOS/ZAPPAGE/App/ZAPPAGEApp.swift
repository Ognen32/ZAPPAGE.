import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FacebookCore
import UserNotifications

@main
struct ZAPPAGEApp: App {
    @State private var isAuthenticated: Bool
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background: scheduleReadingReminder()
            case .active:     cancelReadingReminder()
            default:          break
            }
        }
    }
}

// MARK: - Reading reminder

private func scheduleReadingReminder() {
    let store = LibraryStore.shared

    // Most recently read comic that isn't finished
    guard let latest = store.comics
        .filter({ !store.isRead(id: $0.id) })
        .compactMap({ comic -> (LibraryComic, Date)? in
            guard let lastRead = store.readingProgress[comic.id]?.lastReadAt else { return nil }
            return (comic, lastRead)
        })
        .sorted(by: { $0.1 > $1.1 })
        .first
    else { return }

    let content = UNMutableNotificationContent()
    content.title = "Continue Reading"
    content.body  = "Pick up \"\(latest.0.title)\" where you left off"
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 20, repeats: false)
    let request  = UNNotificationRequest(identifier: "zappage-reading-reminder",
                                         content: content, trigger: trigger)

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        guard granted else { return }
        UNUserNotificationCenter.current().add(request)
    }
}

private func cancelReadingReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: ["zappage-reading-reminder"]
    )
}
