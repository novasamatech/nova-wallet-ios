import Foundation
import Keystore_iOS

extension LegalConsentRepository {
    static let shared: LegalConsentRepositoryProtocol = LegalConsentRepository(
        fetchFactory: LegalDocumentsFetchOperationFactory(),
        settingsManager: SettingsManager.shared,
        logger: Logger.shared
    )
}
