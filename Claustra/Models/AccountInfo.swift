import Foundation

struct AccountInfo {
    var emailAddress: String = ""
    var displayName: String = ""
    var billingType: String = ""
    var subscriptionType: String = ""
    var rateLimitTier: String = ""
    var organizationRole: String?
}

struct KeychainCredentials: Codable {
    struct OAuthData: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: String?
        let subscriptionType: String?
        let rateLimitTier: String?
    }

    let claudeAiOauth: OAuthData?

    enum CodingKeys: String, CodingKey {
        case claudeAiOauth
    }
}
