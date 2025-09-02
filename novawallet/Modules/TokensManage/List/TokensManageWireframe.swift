import Foundation
import UIKit_iOS

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

    func showEditToken(
        from view: TokensManageViewProtocol?,
        token: MultichainToken,
        allChains: [ChainModel.Id: ChainModel]
    ) {
        guard let editView = TokenManageSingleViewFactory.createView(for: token, chains: allChains) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        editView.controller.modalTransitioningFactory = factory
        editView.controller.modalPresentationStyle = .custom

        view?.controller.present(editView.controller, animated: true, completion: nil)
    }
}
