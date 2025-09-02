import Foundation
import Foundation_iOS

class AdvancedExportPresenter: BaseExportPresenter {
    override func updateViewNavbar() {
        view?.updateNavbar(
            with: R.string.localizable.commonAdvanced(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            )
        )
    }
}
