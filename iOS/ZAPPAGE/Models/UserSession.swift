import Observation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class UserSession {
    var username: String = ""
    var email: String    = ""
    var hero: ZapTheme.HeroKind = .zap

    func load() async {
        guard let user = Auth.auth().currentUser else { return }
        username = user.displayName ?? ""
        email    = user.email ?? ""

        let key = "cachedHero_\(user.uid)"

        // Show cached hero instantly
        if let cached = UserDefaults.standard.string(forKey: key),
           let kind   = ZapTheme.HeroKind(rawValue: cached) {
            hero = kind
        }

        // Sync from Firestore and keep cache up to date
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .getDocument()
            if let raw  = doc.data()?["hero"] as? String,
               let kind = ZapTheme.HeroKind(rawValue: raw) {
                hero = kind
                UserDefaults.standard.set(raw, forKey: key)
            }
        } catch {}
    }

    // Called right after signup — caches hero before any Firestore round-trip
    static func cacheHero(_ hero: ZapTheme.HeroKind, uid: String) {
        UserDefaults.standard.set(hero.rawValue, forKey: "cachedHero_\(uid)")
    }
}
