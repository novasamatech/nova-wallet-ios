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

    func showSubnetSelection(
        from view: SubtensorStakingSetupViewProtocol?,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let picker = SubtensorSubnetSelectViewFactory.createPicker(for: state, delegate: delegate) else {
            return
        }

        view?.controller.presentWithCardLayout(picker, animated: true)
    }

    func showSlippageEdit(
        from view: SubtensorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    ) {
        guard let slippageView = SwapSlippageViewFactory.createSubtensorView(
            percent: current,
            chainAsset: state.stakingOption.chainAsset,
            completionHandler: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(slippageView.controller, animated: true)
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
