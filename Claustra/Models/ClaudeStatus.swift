import Foundation

enum ClaudeStatus: String {
    case working  // Actively making API calls (caffeinate started)
    case idle     // Process running but not actively working
    case stopped  // No claude process found

    var displayText: String {
        switch self {
        case .working: return "Working"
        case .idle: return "Idle"
        case .stopped: return "Stopped"
        }
    }

    var statusColor: String {
        switch self {
        case .working: return "green"
        case .idle: return "yellow"
        case .stopped: return "gray"
        }
    }
}
