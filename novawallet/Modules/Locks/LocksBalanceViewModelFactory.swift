import BigInt
import Foundation

protocol LocksBalanceViewModelFactoryProtocol {
    func formatBalance(
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData],
        crowdloans: [ChainModel.Id: [CrowdloanContributionData]],
        locale: Locale
    ) -> FormattedBalance
    func formatPlankValue(
        plank: BigUInt,
        chainAssetId: ChainAssetId,
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> FormattedPlank?
}

struct FormattedBalance {
    let total: String
    let transferrable: String
    let locks: String

    let totalPrice: Decimal
    let transferrablePrice: Decimal
    let locksPrice: Decimal
}

struct FormattedPlank {
    let amount: String
    let price: String?
    let priceValue: Decimal
}

final class LocksBalanceViewModelFactory: LocksBalanceViewModelFactoryProtocol {
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let currencyManager: CurrencyManagerProtocol

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
        self.currencyManager = currencyManager
    }

    func formatBalance(
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData],
        crowdloans: [ChainModel.Id: [CrowdloanContributionData]],
        locale: Locale
    ) -> FormattedBalance {
        var totalPrice: Decimal = 0
        var transferrablePrice: Decimal = 0
        var locksPrice: Decimal = 0
        var lastPriceData: PriceData?

        for balance in balances {
            let priceData = prices[balance.chainAssetId] ?? .zero()

            guard let assetPrecision = chains[balance.chainAssetId.chainId]?
                .asset(for: balance.chainAssetId.assetId)?
                .precision else {
                continue
            }

            let rate = Decimal(string: priceData.price) ?? 0.0

            totalPrice += calculateAmount(
                from: balance.totalInPlank,
                precision: assetPrecision,
                rate: rate
            )
            transferrablePrice += calculateAmount(
                from: balance.transferable,
                precision: assetPrecision,
                rate: rate
            )
            locksPrice += calculateAmount(
                from: balance.locked,
                precision: assetPrecision,
                rate: rate
            )

            lastPriceData = priceData
        }

        let crowdloansTotalPrice: Decimal = crowdloans.reduce(0) { result, crowdloan in
            guard let asset = chains[crowdloan.key]?.utilityAsset() else {
                return result
            }
            let priceData = prices[.init(chainId: crowdloan.key, assetId: asset.assetId)]
            let rate = priceData.map { Decimal(string: $0.price) ?? 0 } ?? 0
            return result + calculateAmount(
                from: crowdloan.value.reduce(0) { $0 + $1.amount },
                precision: asset.precision,
                rate: rate
            )
        }

        let formattedTotal = formatPrice(
            amount: totalPrice + crowdloansTotalPrice,
            priceData: lastPriceData,
            locale: locale
        )
        let formattedTransferrable = formatPrice(amount: transferrablePrice, priceData: lastPriceData, locale: locale)
        let formattedLocks = formatPrice(
            amount: locksPrice + crowdloansTotalPrice,
            priceData: lastPriceData,
            locale: locale
        )
        return .init(
            total: formattedTotal,
            transferrable: formattedTransferrable,
            locks: formattedLocks,
            totalPrice: totalPrice,
            transferrablePrice: transferrablePrice,
            locksPrice: locksPrice
        )
    }

    func formatPlankValue(
        plank: BigUInt,
        chainAssetId: ChainAssetId,
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> FormattedPlank? {
        guard let assetPrecision = chains[chainAssetId.chainId]?.asset(for: chainAssetId.assetId)?.precision,
              let utilityAsset = chains[chainAssetId.chainId]?.utilityAsset() else {
            return nil
        }

        let priceData = prices[chainAssetId]

        let rate = priceData.map { Decimal(string: $0.price) ?? 0 } ?? 0

        let price = calculateAmount(
            from: plank,
            precision: assetPrecision,
            rate: rate
        )

        let amount = calculateAmount(
            from: plank,
            precision: utilityAsset.precision,
            rate: nil
        )
        let formattedAmount = formatAmount(
            amount,
            assetDisplayInfo: utilityAsset.displayInfo,
            locale: locale
        )

        let formattedPrice = formatPrice(amount: price, priceData: priceData, locale: locale)
        return .init(
            amount: formattedAmount,
            price: formattedPrice,
            priceValue: price
        )
    }

    private func calculateAmount(from plank: BigUInt, precision: UInt16, rate: Decimal?) -> Decimal {
        let amount = Decimal.fromSubstrateAmount(
            plank,
            precision: Int16(precision)
        ) ?? 0.0

        return rate.map {
            amount * $0
        } ?? amount
    }

    private func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }

    private func formatAmount(
        _ amount: Decimal,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}
