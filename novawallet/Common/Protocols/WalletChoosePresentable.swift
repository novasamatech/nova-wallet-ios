import Foundation

protocol WalletChoosePresentable: AnyObject {
    func showWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        delegate: WalletsChooseDelegate,
        filter: WalletListFilterProtocol?
    )

    func closeWalletChoose(on view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

extension WalletChoosePresentable {
    func showWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        delegate: WalletsChooseDelegate,
        filter: WalletListFilterProtocol? = nil
    ) {
        guard
            let chooseView = WalletsChooseViewFactory.createView(
                for: selectedWalletId,
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

    func closeWalletChoose(on view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
