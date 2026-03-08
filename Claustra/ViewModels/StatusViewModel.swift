import Foundation
import Combine

@MainActor
final class StatusViewModel: ObservableObject {
    @Published var claudeStatus: ClaudeStatus = .stopped
    @Published var accountInfo: AccountInfo?
    @Published var usageData: UsageData?
    @Published var sessionTokens: SessionTokens?
    @Published var isLoadingUsage = false
    @Published var usageError: String?
    @Published var usageFetchedAt: Date?
    @Published var activeSessionId: String?

    private let hookInstaller = HookInstaller()
    private let hookSessionManager: HookSessionManager
    private let keychainService = KeychainService()
    private lazy var usageAPIService = UsageAPIService(keychainService: keychainService)
    private let configReader = ConfigReader()
    private let usageCachePath: String

    /// In-memory cache of last known active session (cleared on restart)
    private var lastKnownSession: ActiveSession?

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        hookSessionManager = HookSessionManager(sessionsDir: hookInstaller.sessionsDir)
        usageCachePath = "\(hookInstaller.appSupportDir)/usage_cache.json"
    }

    func start() {
        hookInstaller.install()
        hookSessionManager.startWatching()

        // Load cached usage from disk
        loadUsageCache()

        hookSessionManager.$claudeStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.claudeStatus = status
            }
            .store(in: &cancellables)

        // Track last known active session in-memory
        hookSessionManager.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                if let session = session {
                    self?.lastKnownSession = session
                }
            }
            .store(in: &cancellables)

        refreshAccountInfo()
        refreshSessionTokens()

        // Periodic refresh for non-API data only
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.refreshSessionTokens()
            }
        }
    }

    func stop() {
        hookSessionManager.stopWatching()
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
    }

    /// Called when popover opens - refresh local data only, no API call
    func refresh() {
        refreshAccountInfo()
        refreshSessionTokens()
    }

    /// Force refresh usage - the only way to fetch usage API
    func forceRefreshUsage() {
        keychainService.clearCache()
        refreshAccountInfo()
        Task { await fetchUsage() }
    }

    private func refreshAccountInfo() {
        if var info = configReader.readAccountInfo() {
            if let tokenInfo = keychainService.getToken() {
                info.subscriptionType = tokenInfo.subscriptionType
                info.rateLimitTier = tokenInfo.rateLimitTier
            }
            accountInfo = info
        }
    }

    private func fetchUsage() async {
        isLoadingUsage = true
        usageError = nil
        switch await usageAPIService.fetchUsage() {
        case .success(let data):
            usageData = data
            usageFetchedAt = Date()
            saveUsageCache(data: data, fetchedAt: Date())
        case .error(let message):
            usageError = message
        }
        isLoadingUsage = false
    }

    private func refreshSessionTokens() {
        // Priority 1: currently active hook session
        if let active = hookSessionManager.activeSession, !active.sessionId.isEmpty {
            if let tokens = configReader.readSessionTokensForActiveSession(
                projectPath: active.cwd,
                sessionId: active.sessionId
            ) {
                sessionTokens = tokens
                activeSessionId = tokens.sessionId
                return
            }
        }

        // Priority 2: last known active session (in-memory, cleared on restart)
        if let last = lastKnownSession, !last.sessionId.isEmpty {
            if let tokens = configReader.readSessionTokensForActiveSession(
                projectPath: last.cwd,
                sessionId: last.sessionId
            ) {
                sessionTokens = tokens
                activeSessionId = tokens.sessionId
                return
            }
        }

        // Priority 3: most recently modified JSONL
        let tokens = configReader.readSessionTokens()
        sessionTokens = tokens
        activeSessionId = tokens?.sessionId
    }

    // MARK: - Usage Disk Cache

    private struct UsageCache: Codable {
        let data: UsageData
        let fetchedAt: Date
    }

    private func saveUsageCache(data: UsageData, fetchedAt: Date) {
        let cache = UsageCache(data: data, fetchedAt: fetchedAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let jsonData = try? encoder.encode(cache) else { return }
        try? jsonData.write(to: URL(fileURLWithPath: usageCachePath))
    }

    private func loadUsageCache() {
        guard let data = FileManager.default.contents(atPath: usageCachePath) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let cache = try? decoder.decode(UsageCache.self, from: data) else { return }
        usageData = cache.data
        usageFetchedAt = cache.fetchedAt
    }
}
