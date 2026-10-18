import Foundation
import UIKit

final class SubtensorStakeSetupWireframe: SubtensorStakeSetupWireframeProtocol {
    let state: SubtensorSharedStateProtocol

    var assetListObservable: AssetListModelObservable { state.flowState.assetListObservable }

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }

    func showAllSubnets(
        from view: SubtensorStakeSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let picker = SubtensorSubnetSelectViewFactory.createPicker(
            for: state, delegate: delegate, browseState: browseState
        ) else { return }
        view?.controller.presentWithCardLayout(picker, animated: true)
    }

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        model: SubtensorConfirmModel
    ) {
        guard let confirmView = SubtensorConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showValidatorSelection(
        from view: SubtensorStakeSetupViewProtocol?,
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
        from view: SubtensorStakeSetupViewProtocol?,
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

    func showRootDetails(
        from view: SubtensorStakeSetupViewProtocol?,
        browseState: SubtensorSubnetBrowseState
    ) {
        guard let detailsView = SubtensorStakeSetupViewFactory.createRootDetailsView(
            for: state,
            browseState: browseState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }

    func showSlippageSettings(
        from view: SubtensorStakeSetupViewProtocol?,
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
        from view: SubtensorStakeSetupViewProtocol?,
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
