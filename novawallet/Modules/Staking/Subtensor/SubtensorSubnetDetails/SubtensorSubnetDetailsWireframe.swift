import UIKit

final class SubtensorSubnetDetailsWireframe: SubtensorSubnetDetailsWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let validators = SubtensorValidatorSelectViewFactory.createView(
            for: state,
            target: target,
            delegate: delegate
        ) else { return }
        view?.controller.navigationController?.pushViewController(validators.controller, animated: true)
    }

    func complete(from view: SubtensorSubnetDetailsViewProtocol?) {
        guard let navigation = view?.controller.navigationController,
              let setup = navigation.viewControllers.first else { return }
        navigation.popToViewController(setup, animated: true)
    }
}
