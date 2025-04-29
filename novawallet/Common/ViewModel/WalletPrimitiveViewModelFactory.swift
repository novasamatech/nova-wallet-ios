import Foundation
import SubstrateSdk

protocol WalletPrimitiveViewModelProtocol {
    func createHeader(from walletType: MetaAccountModelType, locale: Locale) -> TitleIconViewModel?
    func createWalletInfo(from wallet: MetaAccountModel) -> WalletView.ViewModel.WalletInfo
    func hasHeader(for walletType: MetaAccountModelType) -> Bool
}

final class WalletPrimitiveViewModelFactory: WalletPrimitiveViewModelProtocol {
    private lazy var iconGenerator = NovaIconGenerator()

    func hasHeader(for walletType: MetaAccountModelType) -> Bool {
        switch walletType {
        case .secrets:
            false
        case .watchOnly, .polkadotVault, .paritySigner, .ledger, .proxied, .genericLedger, .multisig:
            true
        }
    }

    func createHeader(from walletType: MetaAccountModelType, locale: Locale) -> TitleIconViewModel? {
        switch walletType {
        case .secrets:
            return nil
        case .paritySigner:
            return .init(
                title: ParitySignerType.legacy.getName(for: locale).uppercased(),
                icon: ParitySignerType.legacy.icon
            )
        case .polkadotVault:
            return .init(
                title: ParitySignerType.legacy.getName(for: locale).uppercased(),
                icon: ParitySignerType.vault.icon
            )
        case .ledger:
            return .init(
                title: R.string.localizable.commonLedgerLegacy(
                    preferredLanguages: locale.rLanguages
                ).uppercased(),
                icon: R.image.iconLedgerWarning()
            )
        case .proxied:
            return .init(
                title: R.string.localizable.commonProxieds(
                    preferredLanguages: locale.rLanguages
                ).uppercased(),
                icon: R.image.iconProxy()
            )
        case .multisig:
            return .init(
                title: R.string.localizable.commonMultisig(
                    preferredLanguages: locale.rLanguages
                ).uppercased(),
                icon: R.image.iconMultisig()
            )
        case .watchOnly:
            return .init(
                title: R.string.localizable.commonWatchOnly(
                    preferredLanguages: locale.rLanguages
                ).uppercased(),
                icon: R.image.iconWatchOnly()
            )
        case .genericLedger:
            return .init(
                title: R.string.localizable.commonLedger(
                    preferredLanguages: locale.rLanguages
                ).uppercased(),
                icon: R.image.iconLedger()
            )
        }
    }

    func createWalletInfo(from wallet: MetaAccountModel) -> WalletView.ViewModel.WalletInfo {
        let optIcon = wallet.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }

        let iconViewModel = optIcon.map {
            IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: wallet.metaId)
        }

        return .init(icon: iconViewModel, name: wallet.name)
    }
}
