import Foundation
import SoraFoundation

class AdvancedExportPresenter: BaseExportPresenter {
    override func updateViewNavbar() {
        view?.updateNavbar(
            with: R.string.localizable.commonAdvanced(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            )
        )
    }
}
