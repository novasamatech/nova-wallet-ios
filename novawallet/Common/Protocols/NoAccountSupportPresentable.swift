import Foundation

protocol NoAccountSupportPresentable {
    func presentNoAccountSupport(
        from view: ControllerBackedProtocol,
        walletType: MetaAccountModelType,
        chainName: String,
        locale: Locale
    )

    func presentAddAccount(
        from view: ControllerBackedProtocol,
        chainName: String,
        message: String,
        locale: Locale,
        addClosure: @escaping () -> Void
    )
}

extension NoAccountSupportPresentable where Self: AlertPresentable {
    func presentNoAccountSupport(
        from view: ControllerBackedProtocol,
        walletType: MetaAccountModelType,
        chainName: String,
        locale: Locale
    ) {
        let title: String

        switch walletType {
        case .secrets, .watchOnly, .proxied:
            let wallet = R.string.localizable.commonWallet(preferredLanguages: locale.rLanguages)
            title = R.string.localizable.commonWalletNotSupportChain(
                wallet,
                chainName,
                preferredLanguages: locale.rLanguages
            )
        case .paritySigner:
            let paritySigner = R.string.localizable.commonParitySigner(preferredLanguages: locale.rLanguages)
            title = R.string.localizable.commonWalletNotSupportChain(
                paritySigner,
                chainName,
                preferredLanguages: locale.rLanguages
            )
        case .polkadotVault, .polkadotVaultRoot:
            let polkadotVault = R.string.localizable.commonPolkadotVault(preferredLanguages: locale.rLanguages)
            title = R.string.localizable.commonWalletNotSupportChain(
                polkadotVault,
                chainName,
                preferredLanguages: locale.rLanguages
            )
        case .ledger, .genericLedger:
            let ledger = R.string.localizable.commonLedger(preferredLanguages: locale.rLanguages)
            title = R.string.localizable.commonWalletNotSupportChain(
                ledger,
                chainName,
                preferredLanguages: locale.rLanguages
            )
        }

        let close = R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        present(message: nil, title: title, closeAction: close, from: view)
    }

    func presentAddAccount(
        from view: ControllerBackedProtocol,
        chainName: String,
        message: String,
        locale: Locale,
        addClosure: @escaping () -> Void
    ) {
        let languages = locale.rLanguages

        let title = R.string.localizable.commonChainAccountMissingTitleFormat(
            chainName,
            preferredLanguages: languages
        )

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: languages),
            style: .destructive
        )

        let addAction = AlertPresentableAction(
            title: R.string.localizable.commonAdd(preferredLanguages: languages),
            handler: addClosure
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, addAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
