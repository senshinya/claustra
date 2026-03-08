import SwiftUI

struct AccountSection: View {
    let accountInfo: AccountInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Account")

            if let info = accountInfo {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(info.emailAddress)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Plan: \(planDisplayName(info))")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    if !info.billingType.isEmpty {
                        Text("(\(info.billingType))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Not signed in")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Parse rateLimitTier like "default_claude_max_5x" → "Max 5x"
    private func planDisplayName(_ info: AccountInfo) -> String {
        let tier = info.rateLimitTier.lowercased()
        if tier.contains("max") {
            // Extract multiplier: "default_claude_max_5x" → "5x", "default_claude_max_20x" → "20x"
            if let range = tier.range(of: #"(\d+x)"#, options: .regularExpression) {
                return "Max \(tier[range].uppercased())"
            }
            return "Max"
        }
        // Fallback to subscriptionType
        return info.subscriptionType.capitalized
    }
}
