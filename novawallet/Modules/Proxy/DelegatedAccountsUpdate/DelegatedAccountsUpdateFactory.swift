import Foundation
import SubstrateSdk

protocol DelegatedAccountsUpdateFactoryProtocol {
    func createViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [ProxyAccountModel.Status],
        chainModelProvider: (ChainModel.Id) -> ChainModel?,
        locale: Locale
    ) -> [ProxyWalletView.ViewModel]
}

final class DelegatedAccountsUpdateFactory: DelegatedAccountsUpdateFactoryProtocol {
    private lazy var iconGenerator = NovaIconGenerator()

    func createViewModels(
        for wallets: [ManagedMetaAccountModel],
        statuses: [ProxyAccountModel.Status],
        chainModelProvider: (ChainModel.Id) -> ChainModel?,
        locale: Locale
    ) -> [ProxyWalletView.ViewModel] {
        let viewModels: [ProxyWalletView.ViewModel] = wallets.filter { $0.info.type == .proxied }.compactMap { wallet in
            guard let chainAccount = wallet.info.chainAccounts.first(where: { $0.proxy != nil }),
                  let proxy = chainAccount.proxy,
                  statuses.contains(proxy.status),
                  let proxyWallet = wallets.first(where: { $0.info.has(
                      accountId: proxy.accountId,
                      chainId: chainAccount.chainId
                  ) && $0.info.type != .proxied })
            else {
                return nil
            }

            let optIcon = wallet.info.walletIdenticonData().flatMap {
                try? iconGenerator.generateFromAccountId($0)
            }
            let iconViewModel = optIcon.map {
                IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: wallet.info.metaId)
            }
            let optSubtitleDetailsIcon = proxyWallet.info.walletIdenticonData().flatMap {
                try? iconGenerator.generateFromAccountId($0)
            }
            let subtitleDetailsIconViewModel = optSubtitleDetailsIcon.map {
                IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: proxyWallet.info.metaId)
            }
            let chainModel = chainModelProvider(chainAccount.chainId)
            let chainIcon = chainModel.map { RemoteImageViewModel(url: $0.icon) }

            return ProxyWalletView.ViewModel(
                icon: iconViewModel,
                networkIcon: chainIcon,
                name: wallet.info.name,
                subtitle: proxy.type.subtitle(locale: locale),
                subtitleDetailsIcon: subtitleDetailsIconViewModel,
                subtitleDetails: proxyWallet.info.name
            )
        }

        return viewModels
    }
}
