import Foundation
import UIKit
import UIKit_iOS

protocol StakingWarningPresentable {
    func presentStakingWarning(
        for url: URL,
        from presentingController: UIViewController?,
        delegate: DAppStakingWarningViewDelegate
    )
}

extension StakingWarningPresentable {
    func presentStakingWarning(
        for url: URL,
        from presentingController: UIViewController?,
        delegate: DAppStakingWarningViewDelegate
    ) {
        guard let warningView = DAppStakingWarningViewFactory.createView(
            for: url,
            delegate: delegate
        ) else { return }

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.novaManual
        )
        warningView.controller.modalTransitioningFactory = factory
        warningView.controller.modalPresentationStyle = .custom

        presentingController?.present(
            warningView.controller,
            animated: true,
            completion: nil
        )
    }
}
