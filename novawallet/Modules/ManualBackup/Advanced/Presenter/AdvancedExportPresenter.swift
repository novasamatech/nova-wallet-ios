import Foundation
import Foundation_iOS

class AdvancedExportPresenter: BaseExportPresenter {
    override func updateViewNavbar() {
        view?.updateNavbar(
            with: R.string(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).localizable.commonAdvanced()
        )
    }
}
