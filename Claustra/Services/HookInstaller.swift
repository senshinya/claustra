import Foundation

/// Installs Claustra hooks into ~/.claude/settings.json (appending, not replacing existing hooks).
/// Creates a helper shell script that Claude Code hooks call to write session events to disk.
final class HookInstaller {
    static let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "Stop", "SessionEnd"]

    private let claudeSettingsPath: String
    let appSupportDir: String
    private let hookScriptPath: String
    let sessionsDir: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        claudeSettingsPath = "\(home)/.claude/settings.json"
        appSupportDir = "\(home)/Library/Application Support/Claustra"
        hookScriptPath = "\(appSupportDir)/claustra-hook.sh"
        sessionsDir = "\(appSupportDir)/sessions"
    }

    func install() {
        createDirectories()
        writeHookScript()
        patchClaudeSettings()
    }

    func uninstall() {
        removeFromClaudeSettings()
    }

    // MARK: - Private

    private func createDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: appSupportDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: sessionsDir, withIntermediateDirectories: true)
    }

    private func writeHookScript() {
        let script = """
        #!/bin/bash
        EVENT="$1"
        INPUT=$(cat)
        SID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/.*"session_id":"\\([^"]*\\)".*/\\1/')
        [ -z "$SID" ] && exit 0
        CWD=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | head -1 | sed 's/.*"cwd":"\\([^"]*\\)".*/\\1/')
        DIR="\(sessionsDir)"
        if [ "$EVENT" = "SessionEnd" ]; then
            rm -f "$DIR/$SID.json"
        else
            printf '{"event":"%s","session_id":"%s","cwd":"%s","timestamp":%s}\\n' "$EVENT" "$SID" "$CWD" "$(date +%s)" > "$DIR/$SID.json"
        fi
        """

        try? script.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hookScriptPath
        )
    }

    private func patchClaudeSettings() {
        let fm = FileManager.default
        var settings: [String: Any] = [:]

        // Read existing settings
        if let data = fm.contents(atPath: claudeSettingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        for event in Self.hookEvents {
            var eventHooks = hooks[event] as? [[String: Any]] ?? []

            // Check if Claustra hook already exists - don't add duplicates
            let alreadyInstalled = eventHooks.contains { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { hook in
                    (hook["command"] as? String)?.contains("claustra-hook.sh") == true
                }
            }

            if !alreadyInstalled {
                let hookEntry: [String: Any] = [
                    "matcher": "",
                    "hooks": [
                        [
                            "type": "command",
                            "command": "/bin/bash \"\(hookScriptPath)\" \(event)",
                            "timeout": 5
                        ] as [String: Any]
                    ]
                ]
                eventHooks.append(hookEntry)
            }

            hooks[event] = eventHooks
        }

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: URL(fileURLWithPath: claudeSettingsPath))
        }
    }

    private func removeFromClaudeSettings() {
        let fm = FileManager.default
        guard let data = fm.contents(atPath: claudeSettingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in Self.hookEvents {
            guard var eventHooks = hooks[event] as? [[String: Any]] else { continue }
            eventHooks.removeAll { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { hook in
                    (hook["command"] as? String)?.contains("claustra-hook.sh") == true
                }
            }
            if eventHooks.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = eventHooks
            }
        }

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: URL(fileURLWithPath: claudeSettingsPath))
        }
    }
}
