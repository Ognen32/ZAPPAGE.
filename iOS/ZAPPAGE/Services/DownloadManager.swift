import Foundation
import UIKit
import Observation
import UserNotifications

struct DownloadDisplayInfo {
    let title: String
    let publisher: String?
    let coverImageURL: String?
    let size: String?
    let sourceURL: String
}

enum DownloadStatus {
    case downloading
    case done
    case failed(String)
}

struct DownloadItem: Identifiable {
    let id: String          // sourceURL
    let info: DownloadDisplayInfo
    var progress: Double
    var status: DownloadStatus
    let startedAt: Date
    var task: Task<Void, Never>?
}

// NSObject subclass needed for UNUserNotificationCenterDelegate conformance
private final class DownloadNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Show banners even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@Observable
final class DownloadManager {
    static let shared = DownloadManager()

    var downloads: [String: DownloadItem] = [:]
    private var bgTaskIDs: [String: UIBackgroundTaskIdentifier] = [:]
    private var lastNotifBucket: [String: Int] = [:]
    private let notifDelegate = DownloadNotificationDelegate()

    var hasVisible: Bool { !downloads.isEmpty }

    var sortedDownloads: [DownloadItem] {
        downloads.values.sorted { $0.startedAt < $1.startedAt }
    }

    private init() {
        UNUserNotificationCenter.current().delegate = notifDelegate
    }

    func start(comic: APIComic, detail: ScrapedComicDetail, backendIP: String) {
        guard let sourceURL = comic.url, downloads[sourceURL] == nil else { return }
        let title = comic.title ?? detail.title ?? "Comic"

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let bgID = UIApplication.shared.beginBackgroundTask(withName: "zappage-download") {
            self.cancel(sourceURL: sourceURL)
        }
        bgTaskIDs[sourceURL] = bgID

        let task = Task {
            do {
                _ = try await DownloadService(backendIP: backendIP).download(
                    comic: comic,
                    detail: detail,
                    onProgress: { p in
                        Task { @MainActor in
                            self.downloads[sourceURL]?.progress = p
                            self.maybePostProgress(sourceURL: sourceURL, title: title, progress: p)
                        }
                    }
                )
                await MainActor.run {
                    self.downloads[sourceURL]?.status = .done
                    self.endBgTask(sourceURL: sourceURL)
                    self.postDoneNotification(sourceURL: sourceURL, title: title)
                    self.lastNotifBucket.removeValue(forKey: sourceURL)
                }
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if case .done? = self.downloads[sourceURL]?.status {
                        self.downloads.removeValue(forKey: sourceURL)
                    }
                }
            } catch {
                await MainActor.run {
                    if error is CancellationError {
                        self.downloads.removeValue(forKey: sourceURL)
                    } else {
                        self.downloads[sourceURL]?.status = .failed(error.localizedDescription)
                        self.postFailedNotification(sourceURL: sourceURL, title: title, message: error.localizedDescription)
                    }
                    self.endBgTask(sourceURL: sourceURL)
                    self.lastNotifBucket.removeValue(forKey: sourceURL)
                }
            }
        }

        downloads[sourceURL] = DownloadItem(
            id: sourceURL,
            info: DownloadDisplayInfo(
                title: title,
                publisher: comic.publisher,
                coverImageURL: comic.coverImage ?? detail.coverImage,
                size: comic.size ?? detail.size,
                sourceURL: sourceURL
            ),
            progress: 0.02,
            status: .downloading,
            startedAt: Date(),
            task: task
        )
    }

    func cancel(sourceURL: String) {
        downloads[sourceURL]?.task?.cancel()
        downloads.removeValue(forKey: sourceURL)
        endBgTask(sourceURL: sourceURL)
        removeNotification(for: sourceURL)
        lastNotifBucket.removeValue(forKey: sourceURL)
    }

    func dismiss(sourceURL: String) {
        downloads.removeValue(forKey: sourceURL)
        removeNotification(for: sourceURL)
    }

    private func endBgTask(sourceURL: String) {
        guard let id = bgTaskIDs[sourceURL], id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        bgTaskIDs.removeValue(forKey: sourceURL)
    }

    // MARK: - Notifications

    private func notifID(for sourceURL: String) -> String {
        "zappage-dl-\(abs(sourceURL.hashValue))"
    }

    // Posts at 0 %, 25 %, 50 %, 75 % — replaces previous notification via same identifier
    private func maybePostProgress(sourceURL: String, title: String, progress: Double) {
        let bucket = Int(progress * 4)          // 0,1,2,3
        let last = lastNotifBucket[sourceURL] ?? -1
        guard bucket > last else { return }
        lastNotifBucket[sourceURL] = bucket

        let content = UNMutableNotificationContent()
        content.title = "Downloading Comic"
        content.subtitle = title
        content.body = "\(Int(progress * 100))% downloaded"

        post(notifID(for: sourceURL), content: content)
    }

    private func postDoneNotification(sourceURL: String, title: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\(title) saved to your library"
        content.sound = .default
        post(notifID(for: sourceURL), content: content)
    }

    private func postFailedNotification(sourceURL: String, title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.subtitle = title
        content.body = message
        content.sound = .defaultCritical
        post(notifID(for: sourceURL), content: content)
    }

    private func post(_ id: String, content: UNMutableNotificationContent) {
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func removeNotification(for sourceURL: String) {
        let id = notifID(for: sourceURL)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
