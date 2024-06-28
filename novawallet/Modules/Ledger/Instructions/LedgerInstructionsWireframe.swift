import Foundation

final class LedgerInstructionsWireframe: LedgerInstructionsWireframeProtocol {
    let flow: WalletCreationFlow
    let walletLedgerType: LedgerWalletType

    init(flow: WalletCreationFlow, walletLedgerType: LedgerWalletType) {
        self.flow = flow
        self.walletLedgerType = walletLedgerType
    }

    func showLegacyNetworkSelection(from view: LedgerInstructionsViewProtocol?) {
        guard let networkSelectionView = LedgerNetworkSelectionViewFactory.createView(for: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            networkSelectionView.controller,
            animated: true
        )
    }

    func showGenericDiscovery(from view: LedgerInstructionsViewProtocol?) {
        guard let genericAppDiscoverView = LedgerDiscoverViewFactory.createGenericLedgerView(for: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            genericAppDiscoverView.controller,
            animated: true
        )
    }

    func showOnContinue(from view: LedgerInstructionsViewProtocol?) {
        switch walletLedgerType {
        case .legacy:
            showLegacyNetworkSelection(from: view)
        case .generic:
            showGenericDiscovery(from: view)
        }
    }
}
