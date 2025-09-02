import Foundation
import SubstrateSdk
import UIKit
import Foundation_iOS

protocol ChainAccountViewModelFactoryProtocol {
    func createViewModel(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel

    func createDefinedViewModelItem(for accountId: AccountId, chain: ChainModel) -> ChainAccountViewModelItem
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
            case .secrets, .watchOnly, .ledger, .proxied, .multisig:
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

    private func createAccountList(
        from wallet: MetaAccountModel,
        chains: [ChainModel],
        locale: Locale
    ) -> [ChainAccountViewModelItem] {
        chains.map { chainModel in
            let imageViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chainModel.icon)

            if let accountResponse = wallet.fetch(for: chainModel.accountRequest()) {
                let accountAddress = try? accountResponse.accountId.toAddress(using: chainModel.chainFormat)
                let icon = try? iconGenerator.generateFromAccountId(accountResponse.accountId)

                return ChainAccountViewModelItem(
                    chainId: chainModel.chainId,
                    name: chainModel.name,
                    address: accountAddress,
                    warning: nil,
                    chainIconViewModel: imageViewModel,
                    accountIcon: icon,
                    hasAction: false
                )
            } else {
                return ChainAccountViewModelItem(
                    chainId: chainModel.chainId,
                    name: chainModel.name,
                    address: nil,
                    warning: R.string.localizable.accountNotFoundCaption(preferredLanguages: locale.rLanguages),
                    chainIconViewModel: imageViewModel,
                    accountIcon: nil,
                    hasAction: false
                )
            }
        }
    }

    private func createGenericLedgerSections(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        for locale: Locale
    ) -> ChainAccountListViewModel {
        let ledgerChains = chains.values
            .filter { $0.supportsGenericLedgerApp }
            .sortedUsingDefaultComparator()

        guard wallet.ethereumAddress == nil, ledgerChains.contains(where: { $0.isEthereumBased }) else {
            // no evm chains supported but substrate always defined
            let items = createAccountList(from: wallet, chains: ledgerChains, locale: locale)

            return [
                ChainAccountListSectionViewModel(
                    section: .noSection,
                    chainAccounts: items
                )
            ]
        }

        let substrateChains = ledgerChains.filter { !$0.isEthereumBased }
        let evmChains = ledgerChains.filter { $0.isEthereumBased }

        let substrateItems = createAccountList(from: wallet, chains: substrateChains, locale: locale)
        let substrateTitle = LocalizableResource { locale in
            R.string.localizable.accountsSubstrate(preferredLanguages: locale.rLanguages)
        }

        let evmItems = createAccountList(from: wallet, chains: evmChains, locale: locale)
        let evmTitle = LocalizableResource { locale in
            R.string.localizable.accountsEvm(preferredLanguages: locale.rLanguages)
        }

        let evmAction = LocalizableResource { locale in
            IconWithTitleViewModel(
                icon: R.image.iconBlueAdd(),
                title: R.string.localizable.commonAddAddress(
                    preferredLanguages: locale.rLanguages
                )
            )
        }

        return [
            ChainAccountListSectionViewModel(
                section: .custom(
                    ChainAccountSectionType.Custom(
                        title: evmTitle,
                        action: evmAction
                    )
                ),
                chainAccounts: evmItems
            ),
            ChainAccountListSectionViewModel(
                section: .custom(
                    ChainAccountSectionType.Custom(
                        title: substrateTitle,
                        action: nil
                    )
                ),
                chainAccounts: substrateItems
            )
        ]
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
        switch wallet.type {
        case .secrets, .watchOnly, .paritySigner, .polkadotVault:
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
        case .ledger, .proxied, .multisig:
            let customSecretAccountList = createCustomSecretAccountList(from: wallet, chains: chains, for: locale)
            let sharedSecretAccountList = createSharedSecretAccountList(from: wallet, chains: chains, for: locale)

            let allChainAccounts = customSecretAccountList + sharedSecretAccountList

            let section = ChainAccountListSectionViewModel(section: .noSection, chainAccounts: allChainAccounts)

            return [section]
        case .genericLedger:
            return createGenericLedgerSections(from: wallet, chains: chains, for: locale)
        }
    }
}
