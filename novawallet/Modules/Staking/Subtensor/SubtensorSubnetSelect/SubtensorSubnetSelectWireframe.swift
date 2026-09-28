import Foundation

final class SubtensorSubnetSelectWireframe: SubtensorSubnetSelectWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func complete(from view: SubtensorSubnetSelectViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showDetails(
        from view: SubtensorSubnetSelectViewProtocol?,
        model: SubtensorSubnetSelectViewModel,
        delegate: SubtensorSubnetSelectDelegate
    ) {
        guard let detailsView = SubtensorSubnetDetailsViewFactory.createView(
            for: state,
            model: model,
            delegate: delegate
        ) else { return }

        view?.controller.navigationController?.pushViewController(detailsView.controller, animated: true)
    }
}
