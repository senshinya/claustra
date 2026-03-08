import Foundation

final class KeychainService {
    struct TokenInfo {
        let accessToken: String
        let subscriptionType: String
        let rateLimitTier: String
        let expiresAt: Date?
    }

    private var cachedToken: TokenInfo?

    func getToken() -> TokenInfo? {
        if let cached = cachedToken, let expiresAt = cached.expiresAt, expiresAt > Date() {
            return cached
        }

        guard let json = readKeychainCredentials() else { return nil }
        guard let token = parseCredentials(json) else { return nil }

        cachedToken = token
        return token
    }

    func clearCache() {
        cachedToken = nil
    }

    private func readKeychainCredentials() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func parseCredentials(_ jsonString: String) -> TokenInfo? {
        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            guard let oauth = json["claudeAiOauth"] as? [String: Any],
                  let accessToken = oauth["accessToken"] as? String else {
                return nil
            }

            let subscriptionType = oauth["subscriptionType"] as? String ?? "unknown"
            let rateLimitTier = oauth["rateLimitTier"] as? String ?? "unknown"

            var expiresAt: Date?
            if let expiresAtString = oauth["expiresAt"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                expiresAt = formatter.date(from: expiresAtString)
                if expiresAt == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    expiresAt = formatter.date(from: expiresAtString)
                }
            } else if let expiresAtNum = oauth["expiresAt"] as? TimeInterval {
                expiresAt = Date(timeIntervalSince1970: expiresAtNum / 1000)
            }

            return TokenInfo(
                accessToken: accessToken,
                subscriptionType: subscriptionType,
                rateLimitTier: rateLimitTier,
                expiresAt: expiresAt
            )
        } catch {
            return nil
        }
    }
}
