import Foundation

final class TokensAddSelectNetworkWireframe: TokensAddSelectNetworkWireframeProtocol {
    func showTokenAdd(from view: TokensAddSelectNetworkViewProtocol?, chain: ChainModel) {
        guard let tokenAddView = TokensManageAddViewFactory.createView(for: chain) else {
            return
        }

        view?.controller.navigationController?.pushViewController(tokenAddView.controller, animated: true)
    }
}
