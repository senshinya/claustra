import Foundation

final class ConfigReader {
    private let configPath: String
    private let claudeDir: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        configPath = "\(home)/.claude.json"
        claudeDir = "\(home)/.claude"
    }

    func readAccountInfo() -> AccountInfo? {
        guard let data = readConfigData() else { return nil }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            guard let oauthAccount = json["oauthAccount"] as? [String: Any] else {
                return nil
            }

            var info = AccountInfo()
            info.emailAddress = oauthAccount["emailAddress"] as? String ?? ""
            info.displayName = oauthAccount["displayName"] as? String ?? ""
            info.billingType = oauthAccount["billingType"] as? String ?? ""
            info.organizationRole = oauthAccount["organizationRole"] as? String
            return info
        } catch {
            return nil
        }
    }

    /// Find the most recently active session and return its context info.
    /// Scans all project directories for the most recently modified JSONL file.
    func readSessionTokens() -> SessionTokens? {
        let fm = FileManager.default
        let projectsDir = "\(claudeDir)/projects"

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
            return nil
        }

        var bestJsonlPath: String?
        var bestProjectKey: String?
        var bestSessionId: String?
        var bestMtime: Date = .distantPast

        for dir in projectDirs {
            let dirPath = "\(projectsDir)/\(dir)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = "\(dirPath)/\(file)"
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let mtime = attrs[.modificationDate] as? Date else { continue }
                if mtime > bestMtime {
                    bestMtime = mtime
                    bestJsonlPath = fullPath
                    // Reverse sanitization: "-Users-foo-bar" → "/Users/foo/bar"
                    bestProjectKey = "/" + dir.dropFirst().replacingOccurrences(of: "-", with: "/")
                    bestSessionId = String(file.dropLast(6)) // remove ".jsonl"
                }
            }
        }

        guard let projectKey = bestProjectKey,
              let sessionId = bestSessionId else {
            return nil
        }

        return readSessionTokensForActiveSession(projectPath: projectKey, sessionId: sessionId)
    }

    private struct ContextInfo {
        var contextUsed: Int = 0
        var contextMax: Int = 200_000
        var model: String = ""
    }

    /// Read the last assistant message from session JSONL to get current context usage
    private func readContextFromSession(projectKey: String, sessionId: String) -> ContextInfo {
        // Claude Code sanitizes project paths: "/Users/foo/bar" → "-Users-foo-bar"
        let sanitizedKey = projectKey.replacingOccurrences(of: "/", with: "-")
        let jsonlPath = "\(claudeDir)/projects/\(sanitizedKey)/\(sessionId).jsonl"

        guard let fileHandle = FileHandle(forReadingAtPath: jsonlPath) else {
            return ContextInfo()
        }
        defer { fileHandle.closeFile() }

        // Read last 32KB to find the most recent assistant message
        let fileSize = fileHandle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 32768)
        let offset = fileSize > readSize ? fileSize - readSize : 0
        fileHandle.seek(toFileOffset: offset)

        guard let data = try? fileHandle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else {
            return ContextInfo()
        }

        var info = ContextInfo()

        // Parse lines in reverse to find last assistant message with usage
        let lines = content.components(separatedBy: "\n").reversed()
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let message = entry["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                continue
            }

            let inputTokens = usage["input_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            let cacheCreation = usage["cache_creation_input_tokens"] as? Int ?? 0
            let outputTokens = usage["output_tokens"] as? Int ?? 0

            // Context used ≈ input + cache_read + cache_creation (what was sent to the API)
            info.contextUsed = inputTokens + cacheRead + cacheCreation + outputTokens

            if let model = message["model"] as? String {
                info.model = model
                // Set context max based on model
                if model.contains("opus") || model.contains("sonnet") {
                    info.contextMax = 200_000
                } else if model.contains("haiku") {
                    info.contextMax = 200_000
                }
            }

            break
        }

        return info
    }

    /// Read context info for a specific session by project path and session ID.
    func readSessionTokensForActiveSession(projectPath: String, sessionId: String) -> SessionTokens? {
        let contextInfo = readContextFromSession(projectKey: projectPath, sessionId: sessionId)

        // Must have found at least a model or context data
        guard contextInfo.contextUsed > 0 || !contextInfo.model.isEmpty else { return nil }

        var tokens = SessionTokens()
        tokens.contextUsed = contextInfo.contextUsed
        tokens.contextMax = contextInfo.contextMax
        tokens.model = contextInfo.model
        tokens.sessionId = sessionId

        return tokens
    }

    private func readConfigData() -> Data? {
        return FileManager.default.contents(atPath: configPath)
    }
}
