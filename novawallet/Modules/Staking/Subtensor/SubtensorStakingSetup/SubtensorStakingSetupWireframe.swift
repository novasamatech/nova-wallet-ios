import Foundation
import UIKit

final class SubtensorStakingSetupWireframe: SubtensorStakingSetupWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: SubtensorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    ) {
        guard let confirmView = SubtensorStakingConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showValidatorSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        delegate: SubtensorValidatorSelectDelegate
    ) {
        guard let selectView = SubtensorValidatorSelectViewFactory.createView(
            for: state,
            target: target,
            selectedHotkey: selectedHotkey,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }

    func showSubnetDetails(
        from view: SubtensorStakingSetupViewProtocol?,
        input: SubtensorSubnetDetailsInput,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let detailsView = SubtensorSubnetDetailsViewFactory.createView(
            for: state,
            input: input,
            host: .pushed,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showSlippageSettings(
        from view: SubtensorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    ) {
        guard let settingsView = SwapSlippageViewFactory.createSubtensorSheet(
            percent: current,
            chainAsset: state.stakingOption.chainAsset,
            completionHandler: completion
        ) else {
            return
        }

        view?.controller.present(settingsView.controller, animated: true)
    }

    func popTopControllers(
        from view: SubtensorStakingSetupViewProtocol?,
        completion: @escaping () -> Void
    ) {
        guard let controller = view?.controller else {
            return
        }

        if let presentedViewController = controller.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: completion)
        } else {
            CATransaction.begin()
            CATransaction.setCompletionBlock(completion)

            controller.navigationController?.popToViewController(controller, animated: true)

            CATransaction.commit()
        }
    }
}
