import Foundation
import Foundation_iOS

final class StartStakingInfoSubtensorPreviewWireframe:
    StartStakingInfoSubtensorPreviewWireframeProtocol,
    AlertPresentable,
    CommonRetryable {
    let dataSource: SubtensorStakingPreviewDataSourceProtocol

    init(dataSource: SubtensorStakingPreviewDataSourceProtocol) {
        self.dataSource = dataSource
    }

    func showStrategies(from view: ControllerBackedProtocol?) {
        let strategiesView = SubtensorStakingStrategiesViewFactory.createPreviewView(
            dataSource: dataSource
        )

        view?.controller.navigationController?.pushViewController(
            strategiesView.controller,
            animated: true
        )
    }

    func showManualStaking(from _: ControllerBackedProtocol?) {}

    func presentLoadError(
        from view: ControllerBackedProtocol?,
        retryAction: @escaping () -> Void
    ) {
        presentRequestStatus(
            on: view,
            locale: LocalizationManager.shared.selectedLocale,
            retryAction: retryAction
        )
    }
}
