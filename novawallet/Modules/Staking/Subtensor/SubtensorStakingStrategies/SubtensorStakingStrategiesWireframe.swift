import Foundation
import Foundation_iOS

final class SubtensorStakingStrategiesWireframe: SubtensorStakingStrategiesWireframeProtocol,
    AlertPresentable,
    CommonRetryable {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showStakingSetup(
        from view: ControllerBackedProtocol?,
        strategy _: SubtensorStakingStrategy
    ) {
        guard let setupView = SubtensorStakingSetupViewFactory.createView(
            for: state,
            initialPosition: nil
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }

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

final class SubtensorStakingStrategiesPreviewWireframe:
    SubtensorStakingStrategiesWireframeProtocol,
    AlertPresentable,
    CommonRetryable {
    func showStakingSetup(
        from _: ControllerBackedProtocol?,
        strategy _: SubtensorStakingStrategy
    ) {}

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
