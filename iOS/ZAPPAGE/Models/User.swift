import Foundation

struct ZapUser: Identifiable, Codable {
    let id: String
    var username: String
    var email: String
    var avatarHero: String       // "zap" | "bolt" | "nyx" | "ember"
    var isPremium: Bool
    var issueCount: Int
    var joinedAt: Date
}
