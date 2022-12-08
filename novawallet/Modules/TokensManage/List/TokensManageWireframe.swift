import Foundation
import SoraUI

final class TokensManageWireframe: TokensManageWireframeProtocol {
    func showAddToken(from _: TokensManageViewProtocol?) {
        // TODO: There is a separate task
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
