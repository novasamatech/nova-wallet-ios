import Foundation
import SoraKeystore

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
