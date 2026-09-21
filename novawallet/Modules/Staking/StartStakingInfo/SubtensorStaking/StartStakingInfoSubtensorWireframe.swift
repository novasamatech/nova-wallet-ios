import Foundation

final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe,
    StartStakingInfoSubtensorWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol
    let strategiesDataSource: SubtensorStakingStrategiesDataSourceProtocol

    init(
        state: SubtensorStakingSharedStateProtocol,
        strategiesDataSource: SubtensorStakingStrategiesDataSourceProtocol
    ) {
        self.state = state
        self.strategiesDataSource = strategiesDataSource
    }

    func showStrategies(from view: ControllerBackedProtocol?) {
        let strategiesView = SubtensorStakingStrategiesViewFactory.createView(
            for: state,
            dataSource: strategiesDataSource
        )

        view?.controller.navigationController?.pushViewController(
            strategiesView.controller,
            animated: true
        )
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let setupAmount = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupAmount.controller,
            animated: true
        )
    }
}
