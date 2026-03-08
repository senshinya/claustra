import SwiftUI

struct RunningStatusView: View {
    let status: ClaudeStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .opacity(status == .working ? 1 : 0)
                )

            Text(status.displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .working: return .green
        case .idle: return .yellow
        case .stopped: return .gray
        }
    }
}
