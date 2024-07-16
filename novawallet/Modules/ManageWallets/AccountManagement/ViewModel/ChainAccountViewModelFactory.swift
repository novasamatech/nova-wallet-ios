import Foundation
import SubstrateSdk
import UIKit

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel

    func createDefinedViewModelItem(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModelItem

    func createProxyViewModel(
        proxiedWallet: MetaAccountModel,
        proxyWallet: MetaAccountModel,
        locale: Locale
    ) -> AccountProxyViewModel
}

final class ChainAccountViewModelFactory {
    let iconGenerator: IconGenerating
    private lazy var walletIconGenerator = NovaIconGenerator()

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

            let imageViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chainModel.icon)

            let viewModel = ChainAccountViewModelItem(
                chainId: chainAccount.chainId,
                name: chainName,
                address: accountAddress,
                warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                chainIconViewModel: imageViewModel,
                accountIcon: icon,
                hasAction: true
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

            let warning: String
            let hasAction: Bool

            switch wallet.type {
            case .secrets, .watchOnly, .ledger, .proxied:
                warning = R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages)
                hasAction = true
            case .paritySigner:
                warning = R.string.localizable.paritySignerNotSupportedChain(
                    ParitySignerType.legacy.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                )
                hasAction = accountAddress != nil
            case .polkadotVault:
                warning = R.string.localizable.paritySignerNotSupportedChain(
                    ParitySignerType.vault.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                )

                hasAction = accountAddress != nil
            case .genericLedger:
                guard chainModel.supportsGenericLedgerApp else {
                    return nil
                }

                warning = R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages)
                hasAction = true
            }

            let imageViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chainModel.icon)

            return ChainAccountViewModelItem(
                chainId: chainId,
                name: chainName,
                address: accountAddress,
                warning: warning,
                chainIconViewModel: imageViewModel,
                accountIcon: icon,
                hasAction: hasAction
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

        let imageViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)

        let viewModel = ChainAccountViewModelItem(
            chainId: chain.chainId,
            name: chainName,
            address: accountAddress,
            warning: nil,
            chainIconViewModel: imageViewModel,
            accountIcon: icon,
            hasAction: true
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

        switch wallet.type {
        case .secrets, .watchOnly, .paritySigner, .polkadotVault:
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
        case .ledger, .proxied, .genericLedger:
            let allChainAccounts = customSecretAccountList + sharedSecretAccountList

            let section = ChainAccountListSectionViewModel(section: .noSection, chainAccounts: allChainAccounts)

            return [section]
        }
    }

    func createProxyViewModel(
        proxiedWallet: MetaAccountModel,
        proxyWallet: MetaAccountModel,
        locale: Locale
    ) -> AccountProxyViewModel {
        let optIcon = proxyWallet.walletIdenticonData().flatMap {
            try? walletIconGenerator.generateFromAccountId($0)
        }
        let iconViewModel = optIcon.map {
            DrawableIconViewModel(icon: $0)
        }
        let type = proxiedWallet.proxy()?.type.title(locale: locale) ?? ""

        return .init(
            name: proxyWallet.name,
            icon: iconViewModel,
            type: type
        )
    }
}
