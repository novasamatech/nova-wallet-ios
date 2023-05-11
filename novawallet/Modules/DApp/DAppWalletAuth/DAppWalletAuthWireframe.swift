import Foundation

final class DAppWalletAuthWireframe: DAppWalletAuthWireframeProtocol {
    func close(from view: DAppWalletAuthViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showNetworksResolution(
        from view: DAppWalletAuthViewProtocol?,
        requiredResolution: DAppChainsResolution,
        optionalResolution: DAppChainsResolution?
    ) {
        guard let networksView = ModalNetworksFactory.createResolutionInfoList(
            for: requiredResolution,
            optional: optionalResolution
        ) else {
            return
        }

        view?.controller.present(networksView, animated: true)
    }
}
