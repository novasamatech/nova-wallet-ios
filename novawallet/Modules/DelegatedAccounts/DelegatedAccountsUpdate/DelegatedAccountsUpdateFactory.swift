import Foundation
import SubstrateSdk

private typealias WalletFilter = (ManagedMetaAccountModel) -> Bool
private typealias DelegationInfo = (WalletView.ViewModel.WalletInfo, WalletView.ViewModel.DelegatedAccountInfo)

protocol DelegatedAccountsUpdateFactoryProtocol {
    func createProxiedViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [DelegatedAccount.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel]

    func createMultisigViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [DelegatedAccount.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel]
}

final class DelegatedAccountsUpdateFactory {
    private lazy var iconGenerator = NovaIconGenerator()
}

private extension DelegatedAccountsUpdateFactory {
    func createInfo(
        for wallets: [ManagedMetaAccountModel],
        statuses: [DelegatedAccount.Status],
        chains: [ChainModel.Id: ChainModel],
        walletsFilter: WalletFilter,
        locale: Locale
    ) -> [DelegationInfo] {
        wallets
            .filter { walletsFilter($0) }
            .compactMap { wallet -> DelegationInfo? in
                guard
                    let delegationId = wallet.info.delegationId,
                    let status = wallet.info.delegatedAccountStatus(),
                    statuses.contains(status)
                else {
                    return nil
                }

                let delegateWallet = if let chainId = delegationId.chainId {
                    wallets.first(where: { $0.info.has(
                        accountId: delegationId.delegateAccountId,
                        chainId: chainId
                    ) })
                } else {
                    wallets.first(where: { $0.info.contains(
                        accountId: delegationId.delegateAccountId
                    ) })
                }

                let optIcon = wallet.info.walletIdenticonData().flatMap {
                    try? iconGenerator.generateFromAccountId($0)
                }
                let iconViewModel = optIcon.map {
                    IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: wallet.info.metaId)
                }
                let optSubtitleDetailsIcon = delegateWallet?.info.walletIdenticonData().flatMap {
                    try? iconGenerator.generateFromAccountId($0)
                }
                let subtitleDetailsIconViewModel = delegateWallet.flatMap { delegate in
                    optSubtitleDetailsIcon.map {
                        IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: delegate.info.metaId)
                    }
                }

                var chainIcon: IdentifiableImageViewModelProtocol?

                if let chainId = delegationId.chainId {
                    let chainModel = chains[chainId]
                    chainIcon = ImageViewModelFactory.createIdentifiableChainIcon(from: chainModel?.icon)
                }

                let delegatedInfo = WalletView.ViewModel.DelegatedAccountInfo(
                    networkIcon: chainIcon,
                    type: createSubtitle(for: delegationId.delegationType, locale: locale),
                    pairedAccountIcon: subtitleDetailsIconViewModel,
                    pairedAccountName: delegateWallet?.info.name,
                    isNew: false
                )

                return (
                    .init(icon: iconViewModel, name: wallet.info.name),
                    delegatedInfo
                )
            }
    }

    func createSubtitle(
        for delegationType: DelegationType,
        locale: Locale
    ) -> String {
        switch delegationType {
        case let .proxy(proxyType):
            proxyType.subtitle(locale: locale)
        case .multisig:
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSignatory() + ":"
        }
    }
}

extension DelegatedAccountsUpdateFactory: DelegatedAccountsUpdateFactoryProtocol {
    func createProxiedViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [DelegatedAccount.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel] {
        createInfo(
            for: wallets,
            statuses: statuses,
            chains: chains,
            walletsFilter: { $0.info.type == .proxied },
            locale: locale
        ).map { .init(wallet: $0.0, type: .proxy($0.1)) }
    }

    func createMultisigViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [DelegatedAccount.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel] {
        createInfo(
            for: wallets,
            statuses: statuses,
            chains: chains,
            walletsFilter: { $0.info.type == .multisig },
            locale: locale
        ).map { .init(wallet: $0.0, type: .multisig($0.1)) }
    }
}
