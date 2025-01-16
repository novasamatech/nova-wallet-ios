import Foundation
import Keystore_iOS

extension CurrencyManager {
    static let shared = CurrencyManager()

    private convenience init?() {
        try? self.init(
            currencyRepository: CurrencyRepository.shared,
            settingsManager: SharedSettingsManager() ?? SettingsManager.shared,
            queue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
