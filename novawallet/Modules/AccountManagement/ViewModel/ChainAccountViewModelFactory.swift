import Foundation
import SubstrateSdk
import UIKit

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from _: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel

    func createDefinedViewModelItem(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModelItem
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
            let icon: DrawableIcon?

            if let accountResponse = wallet.fetch(for: chainModel.accountRequest()) {
                accountAddress = try? accountResponse.accountId.toAddress(using: chainModel.chainFormat)
                icon = try? iconGenerator.generateFromAccountId(accountResponse.accountId)
            } else {
                accountAddress = nil
                icon = nil
            }

            let viewModel = ChainAccountViewModelItem(
                chainId: chainAccount.chainId,
                name: chainName,
                address: accountAddress,
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                chainIconViewModel: RemoteImageViewModel(url: chainModel.icon),
                accountIcon: icon
            )

            return viewModel
        }.sorted { viewModel1, viewModel2 in
            guard let chain1 = chains[viewModel1.chainId], let chain2 = chains[viewModel2.chainId] else {
                return chains[viewModel1.chainId] != nil
            }

            return ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
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

            if let accountResponse = wallet.fetch(for: chainModel.accountRequest()) {
                accountAddress = try? accountResponse.accountId.toAddress(using: chainModel.chainFormat)
                icon = try? iconGenerator.generateFromAccountId(accountResponse.accountId)
            } else {
                accountAddress = nil
                icon = nil
            }

            return ChainAccountViewModelItem(
                chainId: chainId,
                name: chainName,
                address: accountAddress,
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                chainIconViewModel: RemoteImageViewModel(url: chainModel.icon),
                accountIcon: icon
            )
        }.sorted { first, second in
            if
                (first.address != nil && second.address != nil) ||
                (first.address == nil && second.address == nil) {
                guard let chain1 = chains[first.chainId], let chain2 = chains[second.chainId] else {
                    return chains[first.chainId] != nil
                }

                return ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
            } else {
                return first.address == nil
            }
        }
    }
}

extension ChainAccountViewModelFactory: ChainAccountViewModelFactoryProtocol {
    func createDefinedViewModelItem(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModelItem {
        let chainName = chain.name

        let accountAddress: String?
        let icon: DrawableIcon?

        accountAddress = try? accountId.toAddress(using: chain.chainFormat)
        icon = try? iconGenerator.generateFromAccountId(accountId)

        let viewModel = ChainAccountViewModelItem(
            chainId: chain.chainId,
            name: chainName,
            address: accountAddress,
            warning: nil,
            chainIconViewModel: RemoteImageViewModel(url: chain.icon),
            accountIcon: icon
        )

        return viewModel
    }

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
