import Foundation

struct SessionTokens {
    // Cumulative session totals (from ~/.claude.json lastModelUsage)
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadInputTokens: Int = 0
    var cacheCreationInputTokens: Int = 0
    var costUSD: Double = 0.0

    // Current context window (from last assistant message in session JSONL)
    var contextUsed: Int = 0        // approximate current context size
    var contextMax: Int = 200_000   // model context window
    var model: String = ""
    var sessionId: String = ""

    var contextPercent: Double {
        guard contextMax > 0 else { return 0 }
        return min(100.0, Double(contextUsed) / Double(contextMax) * 100)
    }

    var formattedContextUsed: String {
        formatTokenCount(contextUsed)
    }

    var formattedContextMax: String {
        formatTokenCount(contextMax)
    }

    var formattedInput: String {
        formatTokenCount(inputTokens)
    }

    var formattedOutput: String {
        formatTokenCount(outputTokens)
    }

    var formattedCacheRead: String {
        formatTokenCount(cacheReadInputTokens)
    }

    var formattedCacheWrite: String {
        formatTokenCount(cacheCreationInputTokens)
    }

    var formattedCost: String {
        String(format: "$%.2f", costUSD)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
