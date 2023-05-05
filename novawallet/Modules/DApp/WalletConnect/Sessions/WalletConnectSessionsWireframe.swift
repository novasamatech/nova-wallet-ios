import Foundation

final class WalletConnectSessionsWireframe: WalletConnectSessionsWireframeProtocol {
    let dappMediator: DAppInteractionMediating

    init(dappMediator: DAppInteractionMediating) {
        self.dappMediator = dappMediator
    }

    func showSession(from view: WalletConnectSessionsViewProtocol?, details: WalletConnectSession) {
        guard
            let detailsView = WalletConnectSessionDetailsViewFactory.createView(
                for: details,
                dappMediator: dappMediator
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    func close(view: WalletConnectSessionsViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
