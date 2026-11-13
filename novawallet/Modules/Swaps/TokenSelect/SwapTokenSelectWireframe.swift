import UIKit

final class SwapTokenSelectWireframe: SwapTokenSelectWireframeProtocol {
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

        view?.controller.present(networksView.controller, animated: true)
    }
}
