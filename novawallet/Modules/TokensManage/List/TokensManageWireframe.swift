import Foundation

final class TokensManageWireframe: TokensManageWireframeProtocol {
    func showAddToken(from view: TokensManageViewProtocol?) {
        guard let networkSelectionView = TokensAddSelectNetworkViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            networkSelectionView.controller,
            animated: true
        )
    }
}
