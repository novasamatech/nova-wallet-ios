import Foundation
import Keystore_iOS
import Operation_iOS

final class LegalConsentRepository {
    private let fetchFactory: LegalDocumentsFetchOperationFactoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private let mutex = NSLock()

    /// Process lifetime cache: a success is cached forever, a failure is never cached so the next
    /// call retries.
    private var documents: [LegalDocument]?

    /// Single flight guard. There is no such primitive in the codebase, so it is explicit here to
    /// keep a burst of callers on one network request.
    private var isSyncing: Bool = false
    private var pendingRequests: [(DispatchQueue, (Bool) -> Void)] = []

    init(
        fetchFactory: LegalDocumentsFetchOperationFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.fetchFactory = fetchFactory
        self.settingsManager = settingsManager
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension LegalConsentRepository {
    /// Must be called with `mutex` held.
    func syncDocumentsIfNeeded() {
        guard !isSyncing else { return }

        isSyncing = true

        execute(
            operation: fetchFactory.fetchOperation(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            self?.handleSync(result: result)
        }
    }

    func handleSync(result: Result<LegalDocumentsRemote, Error>) {
        mutex.lock()

        var consentRequired = false

        switch result {
        case let .success(remote):
            let loadedDocuments = remote.mapToDocuments()

            documents = loadedDocuments

            // A pending acceptance is redeemed inside the lock, after publishing the cache and
            // before answering anyone, so a caller asking right after an onboarding acceptance
            // reads already updated settings.
            if settingsManager.legalConsentPendingSync {
                accept(documents: loadedDocuments)
            }

            consentRequired = isConsentRequired(for: loadedDocuments)
        case let .failure(error):
            // Any throwable lands here: no network, 404, malformed JSON, missing key, malformed
            // date. The app continues normally and does not prompt.
            logger.warning("Legal documents config unavailable: \(error)")
        }

        isSyncing = false

        let requests = pendingRequests
        pendingRequests = []

        mutex.unlock()

        requests.forEach { queue, closure in
            dispatchInQueueWhenPossible(queue) { closure(consentRequired) }
        }
    }

    func isConsentRequired(for documents: [LegalDocument]) -> Bool {
        let acceptedVersions = settingsManager.legalConsentAcceptedVersions

        return documents.contains { document in
            let accepted = acceptedVersions[document.type.rawValue] ?? Constants.nothingAccepted

            return accepted < document.version
        }
    }

    /// Versions are written first and the pending flag cleared last: if the process dies in between
    /// the flag is still set and the next successful sync re-accepts idempotently.
    func accept(documents: [LegalDocument]) {
        var acceptedVersions = settingsManager.legalConsentAcceptedVersions

        documents.forEach { acceptedVersions[$0.type.rawValue] = $0.version }

        settingsManager.legalConsentAcceptedVersions = acceptedVersions
        settingsManager.legalConsentPendingSync = false
    }
}

// MARK: - LegalConsentRepositoryProtocol

extension LegalConsentRepository: LegalConsentRepositoryProtocol {
    func isConsentRequired(runningIn queue: DispatchQueue, completion: @escaping (Bool) -> Void) {
        mutex.lock()

        if let documents {
            let required = isConsentRequired(for: documents)

            mutex.unlock()

            dispatchInQueueWhenPossible(queue) { completion(required) }

            return
        }

        pendingRequests.append((queue, completion))
        syncDocumentsIfNeeded()

        mutex.unlock()
    }

    func acceptCurrentVersions(deferringWhenUnavailable: Bool) {
        mutex.lock()

        defer { mutex.unlock() }

        if let documents {
            accept(documents: documents)
        } else if deferringWhenUnavailable {
            settingsManager.legalConsentPendingSync = true
        }
    }
}

// MARK: - Constants

private extension LegalConsentRepository {
    enum Constants {
        static let nothingAccepted: Int = 0
    }
}
