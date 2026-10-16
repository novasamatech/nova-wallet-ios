import Foundation

final class SubtensorWhereToStakeWireframe: SubtensorWhereToStakeWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol
    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showSetup(from view: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder) {
        let setup = order == .root
            ? SubtensorStakingSetupViewFactory.createRootDetailsView(for: state, presentation: .quickPickRoot)
            : SubtensorStakingSetupViewFactory.createQuickPickView(for: state, order: order)
        guard let setup else { return }
        view?.controller.navigationController?.pushViewController(setup.controller, animated: true)
    }
}
