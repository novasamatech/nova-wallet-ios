import Foundation
import UIKit

struct AccountManagementViewModelParams {
    let wallet: MetaAccountModel
    let delegateWallet: MetaAccountModel?
    let chains: [ChainModel.Id: ChainModel]
    let signatoryInfoAction: (String) -> Void
    let legacyLedgerAction: () -> Void
    let locale: Locale
}

protocol AccountManagementViewModelFactoryProtocol {
    func createViewModel(params: AccountManagementViewModelParams) -> AccountManageWalletViewModel
}

final class AccountManagementViewModelFactory {
    let iconViewModelFactory: IconViewModelFactoryProtocol

    init(iconViewModelFactory: IconViewModelFactoryProtocol = IconViewModelFactory()) {
        self.iconViewModelFactory = iconViewModelFactory
    }
}

// MARK: - Private

private extension AccountManagementViewModelFactory {
    func createMessageType(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        legacyLedgerAction: @escaping () -> Void,
        locale: Locale
    ) -> AccountManageWalletViewModel.MessageType {
        switch wallet.type {
        case .secrets:
            .none
        case .watchOnly:
            .hint(
                text: R.string.localizable.accountManagementWatchOnlyHint(
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconWatchOnly()
            )
        case .paritySigner:
            .hint(
                text: R.string.localizable.paritySignerDetailsHint(
                    ParitySignerType.legacy.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconParitySigner()
            )
        case .polkadotVault:
            .hint(
                text: R.string.localizable.paritySignerDetailsHint(
                    ParitySignerType.vault.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconPolkadotVault()
            )
        case .ledger:
            if chains.contains(where: { $0.value.supportsGenericLedgerApp }) {
                .banner(.createLedgerMigrationDownload(for: locale, action: legacyLedgerAction))
            } else {
                .hint(
                    text: R.string.localizable.ledgerDetailsHint(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconLedger()
                )
            }
        case .proxied:
            .hint(
                text: R.string.localizable.proxyDetailsHint(
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconProxiedWallet()
            )
        case .multisig:
            .hint(
                text: createMultisigMessage(for: wallet.multisigAccount?.anyChainMultisig, locale: locale),
                icon: R.image.iconMultisig()
            )
        case .genericLedger:
            .hint(
                text: R.string.localizable.ledgerDetailsHint(
                    preferredLanguages: locale.rLanguages
                ),
                icon: R.image.iconLedger()
            )
        }
    }

    func createMultisigMessage(
        for multisigContext: DelegatedAccount.MultisigAccountModel?,
        locale: Locale
    ) -> String {
        guard let multisigContext else {
            return R.string.localizable.multisigDetailsHint(
                preferredLanguages: locale.rLanguages
            )
        }

        return [
            R.string.localizable.multisigWalletDetailsThreshold(
                multisigContext.threshold,
                multisigContext.otherSignatories.count + 1,
                preferredLanguages: locale.rLanguages
            ),
            R.string.localizable.multisigDetailsHint(
                preferredLanguages: locale.rLanguages
            )
        ].joined(separator: "\n\n")
    }

    func createContext(
        wallet: MetaAccountModel,
        delegateWallet: MetaAccountModel?,
        chains: [ChainModel.Id: ChainModel],
        signatoryInfoAction: @escaping (String) -> Void,
        locale: Locale
    ) -> AccountManageWalletViewModel.WalletContext? {
        guard let delegateWallet else { return nil }

        switch wallet.type {
        case .multisig:
            guard let multisigContext = createMultisigContext(
                delegateWallet: delegateWallet,
                multisigWallet: wallet,
                chains: chains,
                signatoryInfoAction: signatoryInfoAction,
                locale: locale
            ) else { return nil }

            return .multisig(multisigContext)

        case .proxied:
            let proxyWalletViewModel = createDelegateViewModel(
                delegatedWallet: wallet,
                delegateWallet: delegateWallet,
                locale: locale
            )

            return .proxied(.init(proxy: proxyWalletViewModel))
        default:
            return nil
        }
    }

    func createMultisigContext(
        delegateWallet: MetaAccountModel,
        multisigWallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        signatoryInfoAction: @escaping (String) -> Void,
        locale: Locale
    ) -> AccountManageWalletViewModel.WalletContext.Multisig? {
        guard
            let multisigAccountType = multisigWallet.multisigAccount,
            let multisigAccount = multisigAccountType.anyChainMultisig
        else { return nil }

        let chainFormat: ChainFormat = switch multisigAccountType {
        case let .singleChain(chainAccount):
            if let chain = chains[chainAccount.chainId] {
                chain.chainFormat
            } else {
                .unifiedAddressFormat
            }
        case .universal:
            .unifiedAddressFormat
        }

        let signatoryViewModel = createDelegateViewModel(
            delegatedWallet: multisigWallet,
            delegateWallet: delegateWallet,
            locale: locale
        )

        let otherSignatories = multisigAccount.otherSignatories

        let otherSignatoriesViewModels: [WalletInfoView<WalletView>.ViewModel] = otherSignatories.compactMap {
            guard let address = try? $0.toAddress(using: chainFormat) else { return nil }

            let iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                from: $0,
                chainFormat: chainFormat
            )
            let walletInfo = WalletView.ViewModel.WalletInfo(
                icon: iconViewModel,
                name: address,
                lineBreakMode: .byTruncatingMiddle
            )

            return .init(
                wallet: walletInfo,
                type: .noInfo
            )
        }

        let otherSignatoriesTitle = R.string.localizable.multisigWalletDetailsOtherSignatories(
            preferredLanguages: locale.rLanguages
        )

        return .init(
            signatory: signatoryViewModel,
            otherSignatories: otherSignatoriesViewModels,
            otherSignatoriesTitle: "\(otherSignatoriesTitle):",
            signatoryInfoClosure: signatoryInfoAction
        )
    }

    func createDelegateViewModel(
        delegatedWallet: MetaAccountModel,
        delegateWallet: MetaAccountModel,
        locale: Locale
    ) -> AccountDelegateViewModel {
        let icon = delegateWallet.walletIdenticonData().flatMap {
            iconViewModelFactory.createDrawableIconViewModel(from: $0)
        }

        let type = delegatedWallet.proxy?.type.title(locale: locale) ?? ""

        let marker = AttributedReplacementStringDecorator.marker

        let template = "\(delegateWallet.name) \(marker)"

        let decorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [type],
            attributes: [.foregroundColor: R.color.colorTextSecondary()!]
        )

        let nameWithType = decorator.decorate(attributedString: NSAttributedString(string: template))

        return .init(
            name: nameWithType,
            icon: icon
        )
    }
}

// MARK: - AccountManagementViewModelFactoryProtocol

extension AccountManagementViewModelFactory: AccountManagementViewModelFactoryProtocol {
    func createViewModel(params: AccountManagementViewModelParams) -> AccountManageWalletViewModel {
        let messageType = createMessageType(
            for: params.wallet,
            chains: params.chains,
            legacyLedgerAction: params.legacyLedgerAction,
            locale: params.locale
        )
        let context = createContext(
            wallet: params.wallet,
            delegateWallet: params.delegateWallet,
            chains: params.chains,
            signatoryInfoAction: params.signatoryInfoAction,
            locale: params.locale
        )

        return AccountManageWalletViewModel(
            messageType: messageType,
            context: context
        )
    }
}
