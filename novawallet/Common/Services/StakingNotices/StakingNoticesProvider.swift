import Foundation
import Foundation_iOS

final class StakingNoticesProvider: BaseSyncService, StakingNoticesProviding {
    private let url: URL
    private let session: URLSession
    private let cacheURL: URL
    private let localizationManager: LocalizationManagerProtocol

    private let noticesState = Observable<[ChainModel.Id: StakingNotice]>(state: [:])
    // inFlight is always accessed while mutex is held (performSyncUp and stopSyncUp
    // are both invoked by BaseSyncService while holding mutex).
    private var inFlight: URLSessionTask?

    init(
        url: URL,
        session: URLSession = .shared,
        cacheURL: URL = StakingNoticesProvider.defaultCacheURL(),
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
        self.localizationManager = localizationManager
        super.init(logger: logger)
        loadFromDisk()

        // Re-decode the cached JSON whenever the user switches app language so that
        // notice text updates without waiting for the next network fetch.
        localizationManager.addObserver(with: self, queue: .main) { [weak self] _, _ in
            self?.loadFromDisk()
        }
    }

    static func defaultCacheURL() -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("staking_notices.json")
    }

    // MARK: - StakingNoticesProviding

    func notice(for chainId: ChainModel.Id) -> StakingNotice? {
        mutex.lock()
        defer { mutex.unlock() }
        return noticesState.state[chainId]
    }

    var allNotices: [ChainModel.Id: StakingNotice] {
        mutex.lock()
        defer { mutex.unlock() }
        return noticesState.state
    }

    func refresh() {
        if !getIsActive() { setup() }
        syncUp()
    }

    func subscribe(_ observer: AnyObject, callback: @escaping () -> Void) {
        mutex.lock()
        defer { mutex.unlock() }
        // addObserver with queue: .main → notifications dispatched async to main queue.
        noticesState.addObserver(with: observer, queue: .main) { _, _ in
            callback()
        }
    }

    func unsubscribe(_ observer: AnyObject) {
        mutex.lock()
        defer { mutex.unlock() }
        noticesState.removeObserver(by: observer)
    }

    // MARK: - BaseSyncService

    // Called by BaseSyncService while mutex is already held — do NOT re-lock mutex here.
    override func performSyncUp() {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.clearAndComplete(error)
                return
            }
            if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                self.clearAndComplete(StakingNoticesProviderError.httpStatus(http.statusCode))
                return
            }
            guard let data else {
                self.clearAndComplete(StakingNoticesProviderError.emptyResponse)
                return
            }
            self.applyAndPersist(data)
            self.clearAndComplete(nil)
        }

        // mutex is already held by caller; store directly.
        inFlight = task
        task.resume()
    }

    // Called by BaseSyncService while mutex is already held — do NOT re-lock mutex here.
    override func stopSyncUp() {
        let task = inFlight
        inFlight = nil
        task?.cancel()
    }

    deinit {
        inFlight?.cancel()
    }

    // MARK: - Private

    private func clearAndComplete(_ error: Error?) {
        mutex.lock()
        inFlight = nil
        mutex.unlock()
        complete(error)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        applyAndPersist(data, persistToDisk: false)
    }

    /// Parse + commit + optionally persist. Errors on individual entries skip that entry.
    /// Notices whose `endDate` has passed are filtered out so users never see stale warnings.
    ///
    /// Always acquires `mutex`. Callers must NOT hold `mutex` before invoking this — call
    /// paths: network callback (URLSession bg thread), locale observer (main queue), and
    /// `loadFromDisk` during `init` (no other threads yet).
    private func applyAndPersist(_ data: Data, persistToDisk: Bool = true) {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        var newNotices: [ChainModel.Id: StakingNotice] = [:]
        let decoder = JSONDecoder()
        // Use Nova's own localization manager — it stores the user's in-app language
        // choice in SharedSettings and is the sole authority for the selected locale.
        // iOS-level APIs (Locale.preferredLanguages, Bundle.main.preferredLocalizations)
        // are NOT updated by Nova's language picker and must not be used here.
        decoder.userInfo[.stakingNoticePreferredLocale] = localizationManager.selectedLocalization
        let now = Date()
        for entry in array {
            guard let entryData = try? JSONSerialization.data(withJSONObject: entry),
                  let notice = try? decoder.decode(StakingNotice.self, from: entryData) else {
                continue
            }
            if let endDate = notice.endDate, endDate <= now {
                continue
            }
            newNotices[notice.chainId] = notice
        }

        mutex.lock()
        let stateChanged = (newNotices != noticesState.state)
        if stateChanged {
            // Safe to assign under mutex: notification closures are async-dispatched to .main
            // by dispatchInQueueWhenPossible, so they don't run until after unlock.
            noticesState.state = newNotices
        }
        mutex.unlock()

        if stateChanged, persistToDisk {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}

enum StakingNoticesProviderError: Error {
    case httpStatus(Int)
    case emptyResponse
}
