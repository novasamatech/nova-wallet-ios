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
        case .secrets, .watchOnly, .proxied, .multisig:
            let wallet = R.string(preferredLanguages: locale.rLanguages).localizable.commonWallet()
            title = R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletNotSupportChain(
                wallet,
                chainName
            )
        case .paritySigner:
            let paritySigner = R.string(preferredLanguages: locale.rLanguages).localizable.commonParitySigner()
            title = R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletNotSupportChain(
                paritySigner,
                chainName
            )
        case .polkadotVault:
            let polkadotVault = R.string(preferredLanguages: locale.rLanguages).localizable.commonPolkadotVault()
            title = R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletNotSupportChain(
                polkadotVault,
                chainName
            )
        case .ledger, .genericLedger:
            let ledger = R.string(preferredLanguages: locale.rLanguages).localizable.commonLedger()
            title = R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletNotSupportChain(
                ledger,
                chainName
            )
        }

        let close = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
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

        let title = R.string(preferredLanguages: languages).localizable.commonChainAccountMissingTitleFormat(
            chainName
        )

        let cancelAction = AlertPresentableAction(
            title: R.string(preferredLanguages: languages).localizable.commonCancel(),
            style: .destructive
        )

        let addAction = AlertPresentableAction(
            title: R.string(preferredLanguages: languages).localizable.commonAdd(),
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
