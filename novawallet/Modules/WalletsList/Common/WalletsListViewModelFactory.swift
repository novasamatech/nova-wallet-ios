import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

protocol WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> [WalletsListSectionViewModel]

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> WalletsListViewModel
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
        balancesCalculator: BalancesCalculating,
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels = wallets.filter { wallet in
            WalletsListSectionViewModel.SectionType(walletType: wallet.info.type) == type
        }.map { wallet in
            createItemViewModel(for: wallet, balancesCalculator: balancesCalculator, locale: locale)
        }

        if !viewModels.isEmpty {
            return WalletsListSectionViewModel(type: type, items: viewModels)
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
        let iconViewModel = optIcon.map { DrawableIconViewModel(icon: $0) }

        let totalAmountViewModel = WalletTotalAmountView.ViewModel(
            icon: iconViewModel,
            name: wallet.info.name,
            amount: totalValue
        )

        return WalletsListViewModel(
            identifier: wallet.identifier,
            walletAmountViewModel: totalAmountViewModel,
            isSelected: isSelected(wallet: wallet)
        )
    }

    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        balancesCalculator: BalancesCalculating,
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
            let paritySignerSection = createSection(
                type: .paritySigner,
                wallets: wallets,
                balancesCalculator: balancesCalculator,
                locale: locale
            ) {
            sections.append(paritySignerSection)
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

    func formatPrice(amount: Decimal, locale: Locale) -> String {
        let currencyId = currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}
