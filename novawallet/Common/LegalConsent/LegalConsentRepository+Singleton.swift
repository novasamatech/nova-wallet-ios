import Foundation
import Keystore_iOS

extension LegalConsentRepository {
    static let shared: LegalConsentRepositoryProtocol = LegalConsentRepository(
        fetchFactory: LegalDocumentsFetchOperationFactory(),
        settingsManager: SettingsManager.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )
}
