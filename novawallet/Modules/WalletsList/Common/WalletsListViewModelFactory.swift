import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

protocol WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> [WalletsListSectionViewModel]

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> WalletsListViewModel
}

final class WalletsListViewModelFactory {
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

    func calculateValue(
        chains: [ChainModel.Id: ChainModel],
        balances: [ChainAssetId: BigUInt],
        prices: [ChainAssetId: PriceData],
        includingChainIds: Set<ChainModel.Id>,
        excludingChainIds: Set<ChainModel.Id>
    ) -> Decimal {
        balances.reduce(Decimal.zero) { amount, chainAssetBalance in
            let includingChain = includingChainIds.isEmpty || includingChainIds.contains(chainAssetBalance.key.chainId)
            let excludingChain = excludingChainIds.contains(chainAssetBalance.key.chainId)

            guard
                includingChain, !excludingChain,
                let priceData = prices[chainAssetBalance.key],
                let price = Decimal(string: priceData.price),
                let asset = chains[chainAssetBalance.key.chainId]?.asset(for: chainAssetBalance.key.assetId),
                let decimalBalance = Decimal.fromSubstrateAmount(
                    chainAssetBalance.value,
                    precision: Int16(bitPattern: asset.precision)
                ) else {
                return amount
            }

            return amount + decimalBalance * price
        }
    }

    func calculateTotalValue(
        for wallet: ManagedMetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData]
    ) -> Decimal {
        let chainAccountIds = wallet.info.chainAccounts.map(\.chainId)

        var totalValue: Decimal = 0.0

        if let substrateAccountId = wallet.info.substrateAccountId {
            totalValue += calculateValue(
                chains: chains,
                balances: balances[substrateAccountId] ?? [:],
                prices: prices,
                includingChainIds: Set(),
                excludingChainIds: Set(chainAccountIds)
            )

            let contributions = crowdloanContributions[substrateAccountId]?.filter { !chainAccountIds.contains($0.key) } ?? [:]
            totalValue += calculateCrowdloanContribution(
                contributions,
                chains: chains,
                prices: prices
            )
        }

        if let ethereumAddress = wallet.info.ethereumAddress {
            totalValue += calculateValue(
                chains: chains,
                balances: balances[ethereumAddress] ?? [:],
                prices: prices,
                includingChainIds: Set(),
                excludingChainIds: Set(chainAccountIds)
            )

            let contributions = crowdloanContributions[ethereumAddress]?.filter { !chainAccountIds.contains($0.key) } ?? [:]
            totalValue += calculateCrowdloanContribution(
                contributions,
                chains: chains,
                prices: prices
            )
        }

        wallet.info.chainAccounts.forEach { chainAccount in
            totalValue += calculateValue(
                chains: chains,
                balances: balances[chainAccount.accountId] ?? [:],
                prices: prices,
                includingChainIds: [chainAccount.chainId],
                excludingChainIds: Set()
            )
            let contributions = crowdloanContributions[chainAccount.accountId] ?? [:]
            totalValue += calculateCrowdloanContribution(
                contributions,
                chains: chains,
                prices: prices
            )
        }

        return totalValue
    }

    func createSection(
        type: WalletsListSectionViewModel.SectionType,
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> WalletsListSectionViewModel? {
        let viewModels = wallets
            .filter {
                WalletsListSectionViewModel.SectionType(walletType: $0.info.type) == type
            }
            .map {
                createItemViewModel(
                    for: $0,
                    chains: chains,
                    balances: balances,
                    crowdloanContributions: crowdloanContributions,
                    prices: prices,
                    locale: locale
                )
            }

        if !viewModels.isEmpty {
            return WalletsListSectionViewModel(type: type, items: viewModels)
        } else {
            return nil
        }
    }

    private func calculateCrowdloanContribution(
        _ contributions: [ChainModel.Id: BigUInt],
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData]
    ) -> Decimal {
        contributions.reduce(0) { result, contribution in
            guard let asset = chains[contribution.key]?.utilityAsset(),
                  let priceData = prices[ChainAssetId(chainId: contribution.key, assetId: asset.assetId)],
                  let price = Decimal(string: priceData.price) else {
                return result
            }
            guard let decimalAmount = Decimal.fromSubstrateAmount(
                contribution.value,
                precision: Int16(bitPattern: asset.precision)
            ) else {
                return result
            }

            return result + decimalAmount * price
        }
    }
}

extension WalletsListViewModelFactory: WalletsListViewModelFactoryProtocol {
    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> WalletsListViewModel {
        let totalValueDecimal = calculateTotalValue(
            for: wallet,
            chains: chains,
            balances: balances,
            crowdloanContributions: crowdloanContributions,
            prices: prices
        )

        let price = prices.first(where: { $0.value.currencyId != nil })?.value
        let totalValue = formatPrice(
            amount: totalValueDecimal,
            priceData: price,
            locale: locale
        )

        let optIcon = wallet.info.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }
        let iconViewModel = optIcon.map { DrawableIconViewModel(icon: $0) }

        return WalletsListViewModel(
            identifier: wallet.identifier,
            name: wallet.info.name,
            icon: iconViewModel,
            value: totalValue,
            isSelected: wallet.isSelected
        )
    }

    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> [WalletsListSectionViewModel] {
        var sections: [WalletsListSectionViewModel] = []

        if
            let secretsSection = createSection(
                type: .secrets,
                wallets: wallets,
                chains: chains,
                balances: balances,
                crowdloanContributions: crowdloanContributions,
                prices: prices,
                locale: locale
            ) {
            sections.append(secretsSection)
        }

        if
            let paritySignerSection = createSection(
                type: .paritySigner,
                wallets: wallets,
                chains: chains,
                balances: balances,
                crowdloanContributions: crowdloanContributions,
                prices: prices,
                locale: locale
            ) {
            sections.append(paritySignerSection)
        }

        if
            let ledgerSection = createSection(
                type: .ledger,
                wallets: wallets,
                chains: chains,
                balances: balances,
                crowdloanContributions: crowdloanContributions,
                prices: prices,
                locale: locale
            ) {
            sections.append(ledgerSection)
        }

        if
            let watchOnlySection = createSection(
                type: .watchOnly,
                wallets: wallets,
                chains: chains,
                balances: balances,
                crowdloanContributions: crowdloanContributions,
                prices: prices,
                locale: locale
            ) {
            sections.append(watchOnlySection)
        }

        return sections
    }

    func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}
