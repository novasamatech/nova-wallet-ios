import UIKit
import Foundation_iOS

final class SubtensorUnstakeSetupWireframe: SubtensorUnstakeSetupWireframeProtocol {
    func showConfirm(
        from view: SubtensorUnstakeSetupViewProtocol?,
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        amount: Decimal
    ) {
        guard let confirmView = SubtensorUnstakeConfirmViewFactory.createView(
            chainAsset: chainAsset,
            position: position,
            amount: amount
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }

    func showError(from view: SubtensorUnstakeSetupViewProtocol?, message: String) {
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        let alert = UIAlertController(
            title: R.string(preferredLanguages: languages).localizable.commonErrorGeneralTitle(),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: R.string(preferredLanguages: languages).localizable.commonOk(),
            style: .default
        ))
        view?.controller.present(alert, animated: true)
    }
}
