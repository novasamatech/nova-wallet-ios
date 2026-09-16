import Foundation
import Keystore_iOS
import Operation_iOS

final class LegalConsentRepository {
    private let fetchFactory: LegalDocumentsFetchOperationFactoryProtocol
    private let settingsManager: SettingsManagerProtocol
    private let logger: LoggerProtocol

    private let mutex = NSLock()

    private var documents: [LegalDocument]?

    init(
        fetchFactory: LegalDocumentsFetchOperationFactoryProtocol,
        settingsManager: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.fetchFactory = fetchFactory
        self.settingsManager = settingsManager
        self.logger = logger
    }
}

// MARK: - Private

private extension LegalConsentRepository {
    func handleLoaded(documents loadedDocuments: [LegalDocument]) -> Bool {
        mutex.lock()

        defer { mutex.unlock() }

        documents = loadedDocuments

        if settingsManager.legalConsentPendingSync {
            accept(documents: loadedDocuments)
        }

        return isConsentRequired(for: loadedDocuments)
    }

    func isConsentRequired(for documents: [LegalDocument]) -> Bool {
        let acceptedVersions = settingsManager.legalConsentAcceptedVersions

        return documents.contains { document in
            let accepted = acceptedVersions[document.type.rawValue] ?? Constants.nothingAccepted

            return accepted < document.version
        }
    }

    func accept(documents: [LegalDocument]) {
        var acceptedVersions = settingsManager.legalConsentAcceptedVersions

        documents.forEach { acceptedVersions[$0.type.rawValue] = $0.version }

        settingsManager.legalConsentAcceptedVersions = acceptedVersions
        settingsManager.legalConsentPendingSync = false
    }
}

// MARK: - LegalConsentRepositoryProtocol

extension LegalConsentRepository: LegalConsentRepositoryProtocol {
    func consentRequiredWrapper() -> CompoundOperationWrapper<Bool> {
        mutex.lock()

        let cachedDocuments = documents

        mutex.unlock()

        if let cachedDocuments {
            return .createWithResult(isConsentRequired(for: cachedDocuments))
        }

        let fetchOperation = fetchFactory.fetchOperation()

        let mapOperation = ClosureOperation<Bool> { [weak self] in
            guard let self else { return false }

            do {
                let remote = try fetchOperation.extractNoCancellableResultData()

                return handleLoaded(documents: remote.mapToDocuments())
            } catch {
                logger.warning("Legal documents config unavailable: \(error)")

                return false
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }

    func legalConsentStatusWrapper() -> CompoundOperationWrapper<LegalConsentStatus> {
        mutex.lock()

        let cachedDocuments = documents

        mutex.unlock()

        if let cachedDocuments {
            return .createWithResult(isConsentRequired(for: cachedDocuments) ? .required : .notRequired)
        }

        let fetchOperation = fetchFactory.fetchOperation()

        let mapOperation = ClosureOperation<LegalConsentStatus> { [weak self] in
            guard let self else { return .unavailable }

            do {
                let remote = try fetchOperation.extractNoCancellableResultData()

                return handleLoaded(documents: remote.mapToDocuments()) ? .required : .notRequired
            } catch {
                logger.warning("Legal documents config unavailable: \(error)")

                return .unavailable
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
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
