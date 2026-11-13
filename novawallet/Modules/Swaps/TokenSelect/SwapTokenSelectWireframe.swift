import UIKit

final class SwapTokenSelectWireframe: SwapTokenSelectWireframeProtocol {
    private weak var networksView: SwapTokenSelectNetworksViewProtocol?

    func close(view: SwapTokenSelectViewProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showNetworkSelection(
        from view: SwapTokenSelectViewProtocol?,
        viewModels: [SwapTokenSelectNetworkViewModel],
        completion: @escaping ([ChainModel.Id]) -> Void
    ) {
        guard let networksView = SwapTokenSelectNetworksViewFactory.createView(
            viewModels: viewModels,
            completion: completion
        ) else {
            return
        }

        self.networksView = networksView

        view?.controller.present(networksView.controller, animated: true)
    }

    func presentRoutesRetry(
        on view: SwapTokenSelectViewProtocol?,
        locale: Locale,
        retryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) -> Bool {
        let rootController = view?.controller.viewIfLoaded?.window?.rootViewController
        let topControllerBefore = rootController?.topModalViewController
        let presentingView: ControllerBackedProtocol? = networksView ?? view

        presentRequestStatus(
            on: presentingView,
            locale: locale,
            retryAction: retryAction,
            skipAction: skipAction
        )

        return rootController?.topModalViewController !== topControllerBefore
    }
}
