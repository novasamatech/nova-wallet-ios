import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

protocol WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel]

    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel]

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> WalletsListViewModel

    func createProxyItemViewModel(
        for wallet: ManagedMetaAccountModel,
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListViewModel?
}

class WalletsListViewModelFactory {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let currencyManager: CurrencyManagerProtocol

    private lazy var iconGenerator = NovaIconGenerator()

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

    private func createSection(
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
                return createItemViewModel(for: wallet, locale: locale)
            }
        }

        if !viewModels.isEmpty {
            return WalletsListSectionViewModel(type: type, items: viewModels)
        } else {
            return nil
        }
    }

    private func createProxySection(
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels: [WalletsListViewModel] = wallets.filter { wallet in
            WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) == .proxied
        }.compactMap { wallet -> WalletsListViewModel? in
            createProxyItemViewModel(
                for: wallet,
                wallets: wallets,
                chains: chains,
                locale: locale
            )
        }

        if !viewModels.isEmpty {
            return WalletsListSectionViewModel(type: .proxied, items: viewModels)
        } else {
            return nil
        }
    }
}

extension WalletsListViewModelFactory: WalletsListViewModelFactoryProtocol {
    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
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
            isSelected: isSelected(wallet: wallet)
        )
    }

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        locale _: Locale
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
            isSelected: isSelected(wallet: wallet)
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
        let chainIcon = chainModel.map { RemoteImageViewModel(url: $0.icon) }
        let proxyInfo = WalletView.ViewModel.ProxyInfo(
            networkIcon: chainIcon,
            proxyType: proxy.type.subtitle(locale: locale),
            proxyIcon: subtitleDetailsIconViewModel,
            proxyName: proxyWallet.info.name,
            isNew: proxy.status == .new
        )

        let proxyModel = WalletView.ViewModel(
            wallet: .init(icon: iconViewModel, name: wallet.info.name),
            type: .proxy(proxyInfo)
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletViewModel: proxyModel,
            isSelected: isSelected(wallet: wallet)
        )
    }

    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating,
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

    // swiftlint:disable:next function_body_length
    private func internalCreateSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating?,
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        var sections: [WalletsListSectionViewModel] = []

        if
            let secretsSection = createSection(
                type: .secrets,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(secretsSection)
        }

        if
            let polkadotVaultSection = createSection(
                type: .polkadotVault,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(polkadotVaultSection)
        }

        if
            let paritySignerSection = createSection(
                type: .paritySigner,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(paritySignerSection)
        }

        if
            let genericLedger = createSection(
                type: .genericLedger,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(genericLedger)
        }

        if
            let ledgerSection = createSection(
                type: .ledger,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(ledgerSection)
        }

        if
            let proxySection = createProxySection(
                wallets: wallets,
                chains: chains,
                locale: locale
            ) {
            sections.append(proxySection)
        }

        if
            let watchOnlySection = createSection(
                type: .watchOnly,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(watchOnlySection)
        }

        return sections
    }

    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        internalCreateSectionViewModels(
            for: wallets,
            balancesCalculator: nil,
            chains: chains,
            locale: locale
        )
    }

    func formatPrice(amount: Decimal, locale: Locale) -> String {
        let currencyId = currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetBalanceFormatterFactory.createAssetPriceFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}
