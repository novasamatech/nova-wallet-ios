import SoraUI

protocol YourWalletsPresentable {
    func showYourWallets(
        from view: ControllerBackedProtocol?,
        accounts: [MetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    )
    func hideYourWallets(from view: ControllerBackedProtocol?)
}

extension YourWalletsPresentable {
    func showYourWallets(
        from view: ControllerBackedProtocol?,
        accounts: [MetaAccountChainResponse],
        address: AccountAddress?,
        delegate: YourWalletsDelegate
    ) {
        guard let viewController = YourWalletsViewFactory.createView(
            metaAccounts: accounts,
            address: address,
            delegate: delegate
        ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.controller.modalTransitioningFactory = factory
        viewController.controller.modalPresentationStyle = .custom

        view?.controller.present(viewController.controller, animated: true)
    }

    func hideYourWallets(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
