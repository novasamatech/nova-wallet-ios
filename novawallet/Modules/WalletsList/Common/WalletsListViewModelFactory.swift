import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

protocol WalletsListViewModelFactoryProtocol {
    func createSectionViewModels(
        for wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> [WalletsListSectionViewModel]

    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> WalletsListViewModel
}

final class WalletsListViewModelFactory {
    let priceFormatter: LocalizableResource<TokenFormatter>

    private lazy var iconGenerator = NovaIconGenerator()

    init(priceFormatter: LocalizableResource<TokenFormatter>) {
        self.priceFormatter = priceFormatter
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
        prices: [ChainAssetId: PriceData]
    ) -> Decimal {
        let chainAccountIds = wallet.info.chainAccounts.map(\.chainId)

        var totalValue: Decimal = calculateValue(
            chains: chains,
            balances: balances[wallet.info.substrateAccountId] ?? [:],
            prices: prices,
            includingChainIds: Set(),
            excludingChainIds: Set(chainAccountIds)
        )

        if let ethereumAddress = wallet.info.ethereumAddress {
            totalValue += calculateValue(
                chains: chains,
                balances: balances[ethereumAddress] ?? [:],
                prices: prices,
                includingChainIds: Set(),
                excludingChainIds: Set(chainAccountIds)
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
        }

        return totalValue
    }

    func createSection(
        type: WalletsListSectionViewModel.SectionType,
        wallets: [ManagedMetaAccountModel],
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
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
}

extension WalletsListViewModelFactory: WalletsListViewModelFactoryProtocol {
    func createItemViewModel(
        for wallet: ManagedMetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        balances: [AccountId: [ChainAssetId: BigUInt]],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> WalletsListViewModel {
        let totalValueDecimal = calculateTotalValue(
            for: wallet,
            chains: chains,
            balances: balances,
            prices: prices
        )

        let totalValue = priceFormatter.value(for: locale).stringFromDecimal(totalValueDecimal)

        let optIcon = try? iconGenerator.generateFromAccountId(wallet.info.substrateAccountId)
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
                prices: prices,
                locale: locale
            ) {
            sections.append(secretsSection)
        }

        if
            let watchOnlySection = createSection(
                type: .watchOnly,
                wallets: wallets,
                chains: chains,
                balances: balances,
                prices: prices,
                locale: locale
            ) {
            sections.append(watchOnlySection)
        }

        return sections
    }
}
