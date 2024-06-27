import Foundation

final class LedgerInstructionsWireframe: LedgerInstructionsWireframeProtocol {
    let flow: WalletCreationFlow
    let appType: LedgerWalletType

    init(flow: WalletCreationFlow, appType: LedgerWalletType) {
        self.flow = flow
        self.appType = appType
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
        switch appType {
        case .legacy:
            showLegacyNetworkSelection(from: view)
        case .generic:
            showGenericDiscovery(from: view)
        }
    }
}
