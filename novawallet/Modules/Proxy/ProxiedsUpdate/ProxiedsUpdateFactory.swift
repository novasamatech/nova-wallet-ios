import Foundation
import SubstrateSdk

protocol ProxiedsUpdateFactoryProtocol {
    func createViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [ProxyAccountModel.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel]
}

final class ProxiedsUpdateFactory: ProxiedsUpdateFactoryProtocol {
    private lazy var iconGenerator = NovaIconGenerator()

    func createViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [ProxyAccountModel.Status],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletView.ViewModel] {
        let viewModels: [WalletView.ViewModel] = wallets
            .filter { $0.info.type == .proxied }
            .compactMap { wallet -> WalletView.ViewModel? in
                guard
                    let chainAccount = wallet.info.chainAccounts.first(where: { $0.proxy != nil }),
                    let proxy = chainAccount.proxy,
                    statuses.contains(proxy.status) else {
                    return nil
                }
                
                let proxyWallet = wallets.first(where: { $0.info.has(
                    accountId: proxy.accountId,
                    chainId: chainAccount.chainId
                ) })
                
                let optIcon = wallet.info.walletIdenticonData().flatMap {
                    try? iconGenerator.generateFromAccountId($0)
                }
                let iconViewModel = optIcon.map {
                    IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: wallet.info.metaId)
                }
                let optSubtitleDetailsIcon = proxyWallet?.info.walletIdenticonData().flatMap {
                    try? iconGenerator.generateFromAccountId($0)
                }
                
                let subtitleDetailsIconViewModel = proxyWallet.flatMap { proxy in
                    optSubtitleDetailsIcon.map {
                        IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: proxy.info.metaId)
                    }
                }
                
                let chainModel = chains[chainAccount.chainId]
                let chainIcon = ImageViewModelFactory.createIdentifiableChainIcon(from: chainModel?.icon)
                let proxyInfo = WalletView.ViewModel.ProxyInfo(
                    networkIcon: chainIcon,
                    proxyType: proxy.type.subtitle(locale: locale),
                    proxyIcon: subtitleDetailsIconViewModel,
                    proxyName: proxyWallet?.info.name,
                    isNew: false
                )
                
                return WalletView.ViewModel(
                    wallet: .init(icon: iconViewModel, name: wallet.info.name),
                    type: .proxy(proxyInfo)
                )
            }
        
        return viewModels
    }
}
