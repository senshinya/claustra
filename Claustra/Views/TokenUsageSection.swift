import SwiftUI

struct TokenUsageSection: View {
    let tokens: SessionTokens?
    let sessionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Context")

            if let tokens = tokens {
                // Context usage bar
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        if !tokens.model.isEmpty {
                            Text(shortModelName(tokens.model))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(tokens.formattedContextUsed)/\(tokens.formattedContextMax) tokens (\(Int(tokens.contextPercent))%)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(contextColor(tokens.contextPercent))
                                .frame(width: max(0, geometry.size.width * CGFloat(min(tokens.contextPercent, 100)) / 100), height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                if let sid = sessionId, !sid.isEmpty {
                    HStack(spacing: 4) {
                        Text("Session:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(String(sid.prefix(8)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No session data")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("opus") { return "Opus" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("haiku") { return "Haiku" }
        return model
    }

    private func contextColor(_ percent: Double) -> Color {
        if percent >= 80 { return .red }
        if percent >= 60 { return .orange }
        if percent >= 40 { return .yellow }
        return .blue
    }
}

