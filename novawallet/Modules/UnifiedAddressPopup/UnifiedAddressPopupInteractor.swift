import UIKit
import Keystore_iOS

final class UnifiedAddressPopupInteractor {
    weak var presenter: UnifiedAddressPopupInteractorOutputProtocol?

    let settingsManager: SettingsManagerProtocol

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: UnifiedAddressPopupInteractorInputProtocol

extension UnifiedAddressPopupInteractor: UnifiedAddressPopupInteractorInputProtocol {
    func setup() {
        let hidePopup = settingsManager.hideUnifiedAddressPopup

        presenter?.didReceiveDontShow(hidePopup)
    }

    func setDontShow(_ value: Bool) {
        settingsManager.hideUnifiedAddressPopup = value

        presenter?.didReceiveDontShow(value)
    }
}
