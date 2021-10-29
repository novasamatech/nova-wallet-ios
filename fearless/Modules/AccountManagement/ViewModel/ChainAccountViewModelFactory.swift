import Foundation
import FearlessUtils
import UIKit

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from _: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel
}

final class ChainAccountViewModelFactory {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    private func createCustomSecretAccountList(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> [ChainAccountViewModelItem] {
        wallet.chainAccounts.compactMap { chainAccount in
            guard let chainModel = chains[chainAccount.chainId] else {
                return nil
            }

            let chainName = chainModel.name

            let accountAddress: String?

            if chainModel.isEthereumBased {
                accountAddress = try? chainAccount.accountId.toAddress(using: .ethereum)
            } else {
                accountAddress = try? wallet.substrateAccountId.toAddress(
                    using: ChainFormat.substrate(chainModel.addressPrefix)
                )
            }

            let icon = try? iconGenerator.generateFromAddress(
                wallet.substrateAccountId.toAddress(using: ChainFormat.substrate(42))
            )

            return ChainAccountViewModelItem(
                chainId: chainAccount.chainId,
                name: chainName,
                address: accountAddress,
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                chainIconViewModel: RemoteImageViewModel(url: chainModel.icon),
                accountIcon: icon
            )
        }
    }

    private func createSharedSecretAccountList(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> [ChainAccountViewModelItem] {
        chains.compactMap { (chainId: ChainModel.Id, chainModel: ChainModel) in
            guard wallet.chainAccounts.first(where: { chainAccountModel in
                chainAccountModel.chainId == chainId
            }) == nil else { return nil }

            let chainName = chainModel.name

            let accountAddress: String?
            let icon: DrawableIcon?

            if chainModel.isEthereumBased {
                if let ethereumAddress = wallet.ethereumAddress {
                    accountAddress = ethereumAddress.toHex(includePrefix: true)
                    icon = try? iconGenerator.generateFromAddress(
                        wallet.substrateAccountId.toAddress(using: ChainFormat.substrate(42))
                    )
                } else {
                    accountAddress = nil
                    icon = nil
                }

            } else {
                accountAddress = try? wallet.substrateAccountId.toAddress(
                    using: ChainFormat.substrate(chainModel.addressPrefix)
                )
                icon = try? iconGenerator.generateFromAddress(accountAddress ?? "")
            }

            return ChainAccountViewModelItem(
                chainId: chainId,
                name: chainName,
                address: accountAddress,
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                chainIconViewModel: RemoteImageViewModel(url: chainModel.icon),
                accountIcon: icon
            )
        }
    }
}

extension ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel {
        let customSecretAccountList = createCustomSecretAccountList(from: wallet, chains: chains, for: locale)
        let sharedSecretAccountList = createSharedSecretAccountList(from: wallet, chains: chains, for: locale)

        guard !customSecretAccountList.isEmpty else {
            return [ChainAccountListSectionViewModel(
                section: .sharedSecret,
                chainAccounts: sharedSecretAccountList
            )]
        }

        return [
            ChainAccountListSectionViewModel(
                section: .customSecret,
                chainAccounts: customSecretAccountList
            ),
            ChainAccountListSectionViewModel(
                section: .sharedSecret,
                chainAccounts: sharedSecretAccountList
            )
        ]
    }
}
