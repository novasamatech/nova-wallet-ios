import Foundation

final class SubtensorWhereToStakeWireframe: SubtensorWhereToStakeWireframeProtocol {
    let state: SubtensorSharedStateProtocol
    init(state: SubtensorSharedStateProtocol) { self.state = state }

    func showSetup(from view: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder) {
        let setup = order == .root
            ? SubtensorStakeSetupViewFactory.createRootDetailsView(for: state, presentation: .quickPickRoot)
            : SubtensorStakeSetupViewFactory.createQuickPickView(for: state, order: order)
        guard let setup else { return }
        view?.controller.navigationController?.pushViewController(setup.controller, animated: true)
    }
}
