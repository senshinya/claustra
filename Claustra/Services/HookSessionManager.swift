import Foundation
import Combine

/// Info about the most recently active hook session.
struct ActiveSession {
    let sessionId: String
    let cwd: String
}

/// Watches session event files written by Claude Code hooks and publishes aggregate status.
final class HookSessionManager: ObservableObject {
    @Published var claudeStatus: ClaudeStatus = .stopped
    @Published var activeSession: ActiveSession?

    private let sessionsDir: String
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var fallbackTimer: Timer?
    private let staleTimeout: TimeInterval = 300 // 5 minutes

    init(sessionsDir: String) {
        self.sessionsDir = sessionsDir
    }

    func startWatching() {
        scanSessions()
        startDirectoryWatcher()

        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanSessions()
        }
    }

    func stopWatching() {
        teardownDirectoryWatcher()
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    // MARK: - Directory Watcher

    private func startDirectoryWatcher() {
        fileDescriptor = open(sessionsDir, O_RDONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: DispatchQueue.global(qos: .utility)
        )

        source?.setEventHandler { [weak self] in
            self?.scanSessions()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source?.resume()
    }

    private func teardownDirectoryWatcher() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // MARK: - Session Scanning

    private struct SessionEntry {
        let sessionId: String
        let event: String
        let cwd: String
        let timestamp: TimeInterval
    }

    private func scanSessions() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: sessionsDir) else {
            updateStatus(sessions: [])
            return
        }

        let now = Date().timeIntervalSince1970
        var sessions: [SessionEntry] = []

        for entry in entries where entry.hasSuffix(".json") {
            let path = "\(sessionsDir)/\(entry)"
            guard let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let sessionId = json["session_id"] as? String ?? ""
            let event = json["event"] as? String ?? ""
            let cwd = json["cwd"] as? String ?? ""
            let timestamp = json["timestamp"] as? TimeInterval ?? 0

            // Remove stale sessions (no event for 5 minutes)
            if now - timestamp > staleTimeout {
                try? fm.removeItem(atPath: path)
                continue
            }

            sessions.append(SessionEntry(sessionId: sessionId, event: event, cwd: cwd, timestamp: timestamp))
        }

        updateStatus(sessions: sessions)
    }

    private func updateStatus(sessions: [SessionEntry]) {
        let newStatus: ClaudeStatus
        let newActiveSession: ActiveSession?

        if sessions.isEmpty {
            if isClaudeProcessRunning() {
                newStatus = .idle
            } else {
                newStatus = .stopped
            }
            newActiveSession = nil
        } else {
            let workingEvents: Set<String> = ["SessionStart", "UserPromptSubmit", "PreToolUse"]
            let hasWorking = sessions.contains { workingEvents.contains($0.event) }
            newStatus = hasWorking ? .working : .idle

            // Most recently updated session is the active one
            let latest = sessions.max(by: { $0.timestamp < $1.timestamp })
            if let latest = latest, !latest.sessionId.isEmpty {
                newActiveSession = ActiveSession(sessionId: latest.sessionId, cwd: latest.cwd)
            } else {
                newActiveSession = nil
            }
        }

        DispatchQueue.main.async {
            self.claudeStatus = newStatus
            self.activeSession = newActiveSession
        }
    }

    /// Lightweight fallback for when hooks haven't fired yet
    private func isClaudeProcessRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "claude"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
