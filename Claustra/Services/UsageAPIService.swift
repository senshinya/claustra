import Foundation

enum UsageFetchResult {
    case success(UsageData)
    case error(String)
}

final class UsageAPIService {
    private let endpoint = "https://api.anthropic.com/api/oauth/usage"
    private let keychainService: KeychainService

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
    }

    func fetchUsage() async -> UsageFetchResult {
        guard let tokenInfo = keychainService.getToken() else {
            return .error("No credentials")
        }

        guard let url = URL(string: endpoint) else { return .error("Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokenInfo.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("No response")
            }

            if httpResponse.statusCode == 429 {
                return .error("Rate limited")
            }

            guard httpResponse.statusCode == 200 else {
                return .error("HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let usageData = try decoder.decode(UsageData.self, from: data)
            return .success(usageData)
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
