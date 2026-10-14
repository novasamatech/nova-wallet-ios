import Foundation

final class SubtensorWhereToStakeWireframe: SubtensorWhereToStakeWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol
    init(state: SubtensorStakingSharedStateProtocol) { self.state = state }

    func showSetup(from view: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder) {
        let setup: SubtensorStakingSetupViewProtocol?
        switch order {
        case .root: setup = SubtensorStakingSetupViewFactory.createRootDetailsView(for: state)
        case .poolSize, .age: setup = SubtensorStakingSetupViewFactory.createQuickPickView(for: state, order: order)
        case .apy: return
        }
        guard let setup else { return }
        view?.controller.navigationController?.pushViewController(setup.controller, animated: true)
    }
}
