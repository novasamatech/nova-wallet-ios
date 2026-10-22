import UIKit

final class SubtensorSubnetDetailsWireframe: SubtensorSubnetPickerCompleting, SubtensorCallerPopping {
    let state: SubtensorSharedStateProtocol

    init(state: SubtensorSharedStateProtocol) {
        self.state = state
    }
}

extension SubtensorSubnetDetailsWireframe: SubtensorSubnetDetailsWireframeProtocol {
    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        selectedHotkey: AccountId?,
        analytics: SubtensorValidatorSelectAnalytics,
        delegate: SubtensorValidatorSelectDelegate
    ) {
        guard let validatorsView = SubtensorValidatorSelectViewFactory.createView(
            for: state,
            target: target,
            selectedHotkey: selectedHotkey,
            analytics: analytics,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorsView.controller, animated: true)
    }
}
