import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var viewModel: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Claude Code Status")
                .font(.system(size: 14, weight: .bold))

            Divider()

            // Account
            AccountSection(accountInfo: viewModel.accountInfo)

            Divider()

            // Status
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Status")
                RunningStatusView(status: viewModel.claudeStatus)
            }

            Divider()

            // Usage (with its own refresh button)
            UsageSection(
                usageData: viewModel.usageData,
                isLoading: viewModel.isLoadingUsage,
                error: viewModel.usageError,
                fetchedAt: viewModel.usageFetchedAt,
                onRefresh: { viewModel.forceRefreshUsage() }
            )

            Divider()

            // Context
            TokenUsageSection(tokens: viewModel.sessionTokens, sessionId: viewModel.activeSessionId)

            Divider()

            // Quit
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit Claustra")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 280)
    }
}
