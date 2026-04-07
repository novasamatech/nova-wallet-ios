import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

protocol WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel]
}

extension WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        createSectionViewModels(
            for: wallets,
            balancesCalculator: nil,
            chains: chains,
            locale: locale
        )
    }
}

class WalletsListViewModelFactory {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let currencyManager: CurrencyManagerProtocol

    lazy var iconGenerator = NovaIconGenerator()

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.currencyManager = currencyManager
    }

    func isSelected(wallet: ManagedMetaAccountModel) -> Bool {
        wallet.isSelected
    }

    func createItemViewModel(
        wallet: ManagedMetaAccountModel,
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> WalletsListViewModel {
        let totalValueDecimal = balancesCalculator.calculateTotalValue(for: wallet.info)

        let totalValue = formatPrice(amount: totalValueDecimal, locale: locale)

        let optIcon = wallet.info.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }
        let iconViewModel = optIcon.map { IdentifiableDrawableIconViewModel(
            .init(icon: $0),
            identifier: wallet.info.metaId
        ) }

        let walletViewModel = WalletView.ViewModel(
            wallet: .init(icon: iconViewModel, name: wallet.info.name),
            type: .regular(totalValue)
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: walletViewModel,
            isSelected: isSelected(wallet: wallet),
            isFavourite: wallet.isFavourite
        )
    }

    func createItemViewModel(
        wallet: ManagedMetaAccountModel
    ) -> WalletsListViewModel {
        let optIcon = wallet.info.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }
        let iconViewModel = optIcon.map { IdentifiableDrawableIconViewModel(
            .init(icon: $0),
            identifier: wallet.info.metaId
        ) }

        let walletViewModel = WalletView.ViewModel(
            wallet: .init(icon: iconViewModel, name: wallet.info.name),
            type: .regular("")
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: walletViewModel,
            isSelected: isSelected(wallet: wallet),
            isFavourite: wallet.isFavourite
        )
    }
}

// MARK: - Internal

extension WalletsListViewModelFactory {
    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> WalletsListViewModel {
        createItemViewModel(
            wallet: wallet,
            balancesCalculator: balancesCalculator,
            locale: locale
        )
    }

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel
    ) -> WalletsListViewModel {
        createItemViewModel(wallet: wallet)
    }

    func createMultisigItemViewModel(
        for wallet: ManagedMetaAccountModel,
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListViewModel? {
        guard
            let multisigAccountType = wallet.info.multisigAccount,
            let multisig = multisigAccountType.anyChainMultisig,
            let signatoryWallet = wallets.first(where: { $0.info.isSignatory(for: multisigAccountType) })
        else { return nil }

        var chainIcon: IdentifiableImageViewModelProtocol?

        if case let .singleChain(chainAccount) = multisigAccountType {
            let chainModel = chains[chainAccount.chainId]
            chainIcon = ImageViewModelFactory.createIdentifiableChainIcon(from: chainModel?.icon)
        }

        let optIcon = try? iconGenerator.generateFromAccountId(multisig.accountId)

        let iconViewModel = optIcon.map {
            IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: wallet.info.metaId)
        }
        let optSubtitleDetailsIcon = signatoryWallet.info.walletIdenticonData().flatMap {
            try? iconGenerator.generateFromAccountId($0)
        }
        let subtitleDetailsIconViewModel = optSubtitleDetailsIcon.map {
            IdentifiableDrawableIconViewModel(.init(icon: $0), identifier: signatoryWallet.info.metaId)
        }

        let info = WalletView.ViewModel.DelegatedAccountInfo(
            networkIcon: chainIcon,
            type: R.string(preferredLanguages: locale.rLanguages).localizable.commonSignatory(),
            pairedAccountIcon: subtitleDetailsIconViewModel,
            pairedAccountName: signatoryWallet.info.name,
            isNew: multisig.status == .new
        )

        let viewModel = WalletView.ViewModel(
            wallet: .init(icon: iconViewModel, name: wallet.info.name),
            type: .multisig(info)
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: viewModel,
            isSelected: isSelected(wallet: wallet),
            isFavourite: wallet.isFavourite
        )
    }

    func createProxyItemViewModel(
        for wallet: ManagedMetaAccountModel,
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListViewModel? {
        guard let chainAccount = wallet.info.chainAccounts.first(where: { $0.proxy != nil }),
              let proxy = chainAccount.proxy,
              let proxyWallet = wallets.first(where: { $0.info.has(
                  accountId: proxy.accountId,
                  chainId: chainAccount.chainId
              ) })
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
        let chainModel = chains[chainAccount.chainId]
        let chainIcon = ImageViewModelFactory.createIdentifiableChainIcon(from: chainModel?.icon)
        let proxyInfo = WalletView.ViewModel.DelegatedAccountInfo(
            networkIcon: chainIcon,
            type: proxy.type.subtitle(locale: locale),
            pairedAccountIcon: subtitleDetailsIconViewModel,
            pairedAccountName: proxyWallet.info.name,
            isNew: proxy.status == .new
        )

        let proxyModel = WalletView.ViewModel(
            wallet: .init(icon: iconViewModel, name: wallet.info.name),
            type: .proxy(proxyInfo)
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: proxyModel,
            isSelected: isSelected(wallet: wallet),
            isFavourite: wallet.isFavourite
        )
    }

    func formatPrice(amount: Decimal, locale: Locale) -> String {
        let currencyId = currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetBalanceFormatterFactory.createAssetPriceFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}

// MARK: - Private

extension WalletsListViewModelFactory {
    func createSection(
        type: WalletsListSectionViewModel.SectionType,
        wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels = wallets.filter { wallet in
            WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) == type
        }.map { wallet in
            if let balancesCalculator = balancesCalculator {
                return createItemViewModel(
                    for: wallet,
                    balancesCalculator: balancesCalculator,
                    locale: locale
                )
            } else {
                return createItemViewModel(for: wallet)
            }
        }

        if !viewModels.isEmpty {
            return WalletsListSectionViewModel(type: type, items: viewModels)
        } else {
            return nil
        }
    }

    func createProxySection(
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels: [WalletsListViewModel] = wallets.filter { wallet in
            WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) == .proxied
        }.compactMap { proxiedWallets -> WalletsListViewModel? in
            createProxyItemViewModel(
                for: proxiedWallets,
                wallets: wallets,
                chains: chains,
                locale: locale
            )
        }

        return if !viewModels.isEmpty {
            WalletsListSectionViewModel(type: .proxied, items: viewModels)
        } else {
            nil
        }
    }

    func createMultisigSection(
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels: [WalletsListViewModel] = wallets.filter { wallet in
            WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) == .multisig
        }.compactMap { multisigWallet -> WalletsListViewModel? in
            createMultisigItemViewModel(
                for: multisigWallet,
                wallets: wallets,
                chains: chains,
                locale: locale
            )
        }

        return if !viewModels.isEmpty {
            WalletsListSectionViewModel(type: .multisig, items: viewModels)
        } else {
            nil
        }
    }

    func createSingleItemViewModel(
        for wallet: ManagedMetaAccountModel,
        wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListViewModel? {
        switch WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) {
        case .proxied:
            return createProxyItemViewModel(for: wallet, wallets: wallets, chains: chains, locale: locale)
        case .multisig:
            return createMultisigItemViewModel(for: wallet, wallets: wallets, chains: chains, locale: locale)
        default:
            if let balancesCalculator = balancesCalculator {
                return createItemViewModel(for: wallet, balancesCalculator: balancesCalculator, locale: locale)
            } else {
                return createItemViewModel(for: wallet)
            }
        }
    }

    func createFavouritesSection(
        wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels: [WalletsListViewModel] = wallets
            .filter { $0.isFavourite }
            .compactMap { wallet in
                guard let base = createSingleItemViewModel(
                    for: wallet,
                    wallets: wallets,
                    balancesCalculator: balancesCalculator,
                    chains: chains,
                    locale: locale
                ) else { return nil }

                // Multisig parity with Android: when a favourited multisig has
                // no network-specific chain icon, surface the multisig pencils
                // icon over its identicon so the type stays visible in the
                // Favourites section.
                guard wallet.info.type == .multisig,
                      case let .multisig(info) = base.walletViewModel.type,
                      info.networkIcon == nil,
                      let multisigImage = R.image.iconMultisig()
                else { return base }

                let multisigIconViewModel = IdentifiableStaticImageViewModel(
                    image: multisigImage,
                    identifier: "favourites.multisig.\(wallet.identifier)"
                )
                let updatedInfo = WalletView.ViewModel.DelegatedAccountInfo(
                    networkIcon: multisigIconViewModel,
                    type: info.type,
                    pairedAccountIcon: info.pairedAccountIcon,
                    pairedAccountName: info.pairedAccountName,
                    isNew: info.isNew
                )
                let updatedWalletViewModel = WalletView.ViewModel(
                    wallet: base.walletViewModel.wallet,
                    type: .multisig(updatedInfo)
                )
                return WalletsListViewModel(
                    identifier: base.identifier,
                    walletViewModel: updatedWalletViewModel,
                    isSelected: base.isSelected,
                    isSelectable: base.isSelectable,
                    isFavourite: base.isFavourite,
                    typeBadge: base.typeBadge
                )
            }
        guard !viewModels.isEmpty else { return nil }
        return WalletsListSectionViewModel(type: .favourites, items: viewModels)
    }

    func createSearchResultsSection(
        query: String,
        wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListSectionViewModel {
        let lowered = query.lowercased()
        let normalizedQuery = lowered.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        let proxyTypeKeywords: Set<String> = [
            "any", "nontransfer", "governance", "staking",
            "identityjudgement", "cancelproxy", "auction", "nominationpools"
        ]
        // Prefix-style match only: typing `gov` matches `governance`, but a
        // longer query is never assumed to "be" a proxy keyword. This avoids
        // pulling unrelated wallets in when the query happens to share a
        // substring with a proxy type word.
        let isProxyTypeQuery = !normalizedQuery.isEmpty
            && proxyTypeKeywords.contains { $0.contains(normalizedQuery) }

        let matched = wallets.filter { wallet in
            // Strict proxy type query: only proxied wallets matching the type
            if isProxyTypeQuery {
                guard wallet.info.type == .proxied else { return false }
                for chainAccount in wallet.info.chainAccounts {
                    if let proxy = chainAccount.proxy {
                        let proxyTypeName = "\(proxy.type)".lowercased()
                        if proxyTypeName.contains(normalizedQuery) {
                            return true
                        }
                    }
                }
                return false
            }

            if wallet.info.name.lowercased().contains(lowered) { return true }
            for chainAccount in wallet.info.chainAccounts {
                if let chain = chains[chainAccount.chainId],
                   let addr = try? chainAccount.accountId.toAddress(using: chain.chainFormat),
                   addr.lowercased().contains(lowered) {
                    return true
                }
                if let chain = chains[chainAccount.chainId],
                   chain.name.lowercased().contains(lowered) {
                    return true
                }
            }
            return false
        }
        let viewModels: [WalletsListViewModel] = matched.compactMap { wallet in
            guard let base = createSingleItemViewModel(
                for: wallet,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                chains: chains,
                locale: locale
            ) else { return nil }
            let badge: String?
            switch WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) {
            case .proxied: badge = R.string.localizable.commonProxy(preferredLanguages: locale.rLanguages)
            case .multisig: badge = R.string.localizable.commonMultisig(preferredLanguages: locale.rLanguages)
            default: badge = nil
            }
            return WalletsListViewModel(
                identifier: base.identifier,
                walletViewModel: base.walletViewModel,
                isSelected: base.isSelected,
                isSelectable: base.isSelectable,
                isFavourite: base.isFavourite,
                typeBadge: badge
            )
        }
        return WalletsListSectionViewModel(type: .searchResults, items: viewModels)
    }

    // swiftlint:disable:next function_body_length
    func internalCreateSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        var sections: [WalletsListSectionViewModel] = []

        if let favSection = createFavouritesSection(
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            chains: chains,
            locale: locale
        ) {
            sections.append(favSection)
        }

        if let secretsSection = createSection(
            type: .secrets,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(secretsSection)
        }

        if let polkadotVaultSection = createSection(
            type: .polkadotVault,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(polkadotVaultSection)
        }

        if let paritySignerSection = createSection(
            type: .paritySigner,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(paritySignerSection)
        }

        if let genericLedger = createSection(
            type: .genericLedger,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(genericLedger)
        }

        if let ledgerSection = createSection(
            type: .ledger,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(ledgerSection)
        }

        if let proxySection = createProxySection(
            wallets: wallets,
            chains: chains,
            locale: locale
        ) {
            sections.append(proxySection)
        }

        if let multisigSection = createMultisigSection(
            wallets: wallets,
            chains: chains,
            locale: locale
        ) {
            sections.append(multisigSection)
        }

        if let watchOnlySection = createSection(
            type: .watchOnly,
            wallets: wallets,
            balancesCalculator: balancesCalculator,
            locale: locale
        ) {
            sections.append(watchOnlySection)
        }

        return sections
    }
}

// MARK: - WalletsListViewModelFactoryProtocol

extension WalletsListViewModelFactory: WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        internalCreateSectionViewModels(
            for: wallets,
            balancesCalculator: balancesCalculator,
            chains: chains,
            locale: locale
        )
    }
}
