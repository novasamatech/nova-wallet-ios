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
        guard let importAccountView = AccountImportViewFactory.createViewForReplaceChainAccount(
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

    func showExportAccount(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: AccountManagementViewProtocol?
    ) {
        authorize(animated: true, cancellable: true) { [weak self] success in
            if success {
                self?.performExportPresentation(
                    for: wallet,
                    chain: chain,
                    options: options,
                    locale: locale,
                    from: view
                )
            }
        }
    }

    // MARK: Private

    private func performExportPresentation(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        options: [ExportOption],
        locale: Locale?,
        from view: AccountManagementViewProtocol?
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [AlertPresentableAction] = options.map { option in
            switch option {
            case .mnemonic:
                let title = R.string.localizable.importMnemonic(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showMnemonicExport(for: wallet, chain: chain, from: view)
                }
            case .keystore:
                let title = R.string.localizable.importRecoveryJson(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showKeystoreExport(for: wallet, chain: chain, from: view)
                }
            case .seed:
                let title = R.string.localizable.importRawSeed(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showSeedExport(for: wallet, chain: chain, from: view)
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle
        )

        present(
            viewModel: alertViewModel,
            style: .actionSheet,
            from: view
        )
    }

    private func showMnemonicExport(
        for _: MetaAccountModel,
        chain _: ChainModel,
        from view: AccountManagementViewProtocol?
    ) {
        guard let mnemonicView = ExportMnemonicViewFactory.createViewForAddress("") else {
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
        for _: MetaAccountModel,
        chain _: ChainModel,
        from view: AccountManagementViewProtocol?
    ) {
        guard let seedView = ExportSeedViewFactory.createViewForAddress("") else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            seedView.controller,
            animated: true
        )
    }
}
