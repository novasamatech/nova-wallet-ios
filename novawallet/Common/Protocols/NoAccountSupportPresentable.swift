import Foundation

protocol NoAccountSupportPresentable {
    func presentNoAccountSupport(
        from view: ControllerBackedProtocol,
        walletType: MetaAccountModelType,
        chainName: String,
        locale: Locale
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
        case .secrets, .watchOnly:
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
        case .ledger:
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
}
