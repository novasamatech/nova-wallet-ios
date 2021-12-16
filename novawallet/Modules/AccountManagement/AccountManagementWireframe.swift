import Foundation

final class AccountManagementWireframe: AccountManagementWireframeProtocol, AuthorizationPresentable {
    func showCreateAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        guard let createAccountView = AccountCreateViewFactory.createViewForReplaceChainAccount(
            metaAccountModel: wallet,
            chainModelId: chainId,
            isEthereumBased: isEthereumBased
        ) else {
            return
        }

        let controller = createAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    func showImportAccount(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        let options = SecretSource.displayOptions

        let handler: (Int) -> Void = { [weak self] selectedIndex in
            self?.presentImport(
                from: view,
                secretSource: options[selectedIndex],
                wallet: wallet,
                chainId: chainId,
                isEthereumBased: isEthereumBased
            )
        }

        guard let picker = ModalPickerFactory.createPickerListForSecretSource(
            options: options,
            delegate: self,
            context: ModalPickerClosureContext(handler: handler)
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    func showExportAccount(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [SecretSource],
        from view: AccountManagementViewProtocol?
    ) {
        authorize(animated: true, cancellable: true) { [weak self] success in
            if success {
                self?.performExportPresentation(
                    for: wallet,
                    chain: chain,
                    options: options,
                    from: view
                )
            }
        }
    }

    // MARK: Private

    private func performExportPresentation(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [SecretSource],
        from view: AccountManagementViewProtocol?
    ) {
        let handler: (Int) -> Void = { [weak self] selectedIndex in
            switch options[selectedIndex] {
            case .keystore:
                self?.showKeystoreExport(for: wallet, chain: chain, from: view)
            case .seed:
                self?.showSeedExport(for: wallet, chain: chain, from: view)
            case .mnemonic:
                self?.showMnemonicExport(for: wallet, chain: chain, from: view)
            }
        }

        guard let picker = ModalPickerFactory.createPickerListForSecretSource(
            options: options,
            delegate: self,
            context: ModalPickerClosureContext(handler: handler)
        ) else {
            return
        }

        view?.controller.present(picker, animated: true, completion: nil)
    }

    private func showMnemonicExport(
        for metaAccount: MetaAccountModel,
        chain: ChainModel,
        from view: AccountManagementViewProtocol?
    ) {
        guard let mnemonicView = ExportMnemonicViewFactory.createViewForMetaAccount(metaAccount, chain: chain) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            mnemonicView.controller,
            animated: true
        )
    }

    private func showKeystoreExport(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        from view: AccountManagementViewProtocol?
    ) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(
            with: wallet,
            chain: chain
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            passwordView.controller,
            animated: true
        )
    }

    private func showSeedExport(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        from view: AccountManagementViewProtocol?
    ) {
        guard let seedView = ExportSeedViewFactory.createViewForMetaAccount(wallet, chain: chain) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            seedView.controller,
            animated: true
        )
    }

    private func presentImport(
        from view: ControllerBackedProtocol?,
        secretSource: SecretSource,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        isEthereumBased: Bool
    ) {
        guard let importAccountView = AccountImportViewFactory.createViewForReplaceChainAccount(
            secretSource: secretSource,
            modelId: chainId,
            isEthereumBased: isEthereumBased,
            in: wallet
        ) else {
            return
        }

        let controller = importAccountView.controller
        controller.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(controller, animated: true)
        }
    }
}

extension AccountManagementWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let closureContext = context as? ModalPickerClosureContext else {
            return
        }

        closureContext.process(selectedIndex: index)
    }
}
