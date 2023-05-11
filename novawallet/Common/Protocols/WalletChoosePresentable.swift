import Foundation

protocol WalletChoosePresentable: AnyObject {
    func showWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        delegate: WalletsChooseDelegate
    )

    func closeWalletChoose(on view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

extension WalletChoosePresentable {
    func showWalletChoose(
        from view: ControllerBackedProtocol?,
        selectedWalletId: String,
        delegate: WalletsChooseDelegate
    ) {
        guard
            let chooseView = WalletsChooseViewFactory.createView(
                for: selectedWalletId,
                delegate: delegate
            ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: chooseView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func closeWalletChoose(on view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
