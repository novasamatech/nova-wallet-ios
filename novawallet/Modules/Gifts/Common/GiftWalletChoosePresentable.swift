import Foundation

protocol GiftWalletChoosePresentable: WalletChoosePresentable {
    func showGiftWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        chain: ChainModel,
        delegate: WalletsChooseDelegate,
        filter: WalletListFilterProtocol?
    )
}

extension GiftWalletChoosePresentable {
    func showGiftWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        chain: ChainModel,
        delegate: WalletsChooseDelegate,
        filter: WalletListFilterProtocol? = nil
    ) {
        guard
            let chooseView = WalletsChooseViewFactory.createViewWithChainAccounts(
                for: chain,
                selectedWalletId: selectedWalletId,
                delegate: delegate,
                using: filter
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: chooseView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true
        )
    }
}
