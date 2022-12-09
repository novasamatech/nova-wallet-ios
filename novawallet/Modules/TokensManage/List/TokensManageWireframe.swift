import Foundation
import SoraUI

final class TokensManageWireframe: TokensManageWireframeProtocol {
    func showAddToken(from view: TokensManageViewProtocol?, allChains: [ChainModel.Id: ChainModel]) {
        guard let networkSelectionView = TokensAddSelectNetworkViewFactory.createView(for: allChains) else {
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

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        editView.controller.modalTransitioningFactory = factory
        editView.controller.modalPresentationStyle = .custom

        view?.controller.present(editView.controller, animated: true, completion: nil)
    }
}
