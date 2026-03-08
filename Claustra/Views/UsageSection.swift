import SwiftUI

struct UsageSection: View {
    let usageData: UsageData?
    var isLoading: Bool = false
    var error: String?
    var fetchedAt: Date?
    var onRefresh: () -> Void

    private var staleness: Staleness {
        guard let fetchedAt = fetchedAt else { return .never }
        let age = Date().timeIntervalSince(fetchedAt)
        if age > 300 { return .stale }
        return .fresh
    }

    private enum Staleness {
        case never, fresh, stale
    }

    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 { return "\(hours)h \(remainingMinutes)m ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "Usage")
                Spacer()

                if let fetchedAt = fetchedAt {
                    Text(relativeTimeString(from: fetchedAt))
                        .font(.system(size: 10))
                        .foregroundColor(staleness == .stale ? .orange : .secondary)
                }

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(
                            isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: isLoading
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(isLoading)
                .help("Refresh usage")
            }

            if staleness == .stale {
                Text("Data may be outdated")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }

            if let data = usageData {
                if let fiveHour = data.fiveHour {
                    UsageBar(
                        label: "5 hour",
                        utilization: fiveHour.utilization,
                        resetsIn: fiveHour.resetsInText
                    )
                }

                if let sevenDay = data.sevenDay {
                    UsageBar(
                        label: "7 day",
                        utilization: sevenDay.utilization,
                        resetsIn: sevenDay.resetsInText
                    )
                }

                if let sonnet = data.sevenDaySonnet {
                    UsageBar(
                        label: "Sonnet 7d",
                        utilization: sonnet.utilization,
                        resetsIn: sonnet.resetsInText
                    )
                }
            } else if isLoading {
                Text("Loading...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else if let error = error {
                Text("Error: \(error)")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            } else {
                Text("Click refresh to load")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct UsageBar: View {
    let label: String
    let utilization: Double
    let resetsIn: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(utilizationColor)
                if !resetsIn.isEmpty {
                    Text("(\(resetsIn))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(utilizationColor)
                        .frame(width: max(0, geometry.size.width * CGFloat(min(utilization, 100)) / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var utilizationColor: Color {
        if utilization >= 90 {
            return .red
        } else if utilization >= 70 {
            return .orange
        } else if utilization >= 50 {
            return .yellow
        }
        return .green
    }
}
