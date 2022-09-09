import BigInt
import Foundation

protocol LocksBalanceViewModelFactoryProtocol {
    func formatBalance(
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData],
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
    let price: Decimal
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
        locale: Locale
    ) -> FormattedBalance {
        var totalPrice: Decimal = 0
        var transferrablePrice: Decimal = 0
        var locksPrice: Decimal = 0
        var lastPriceData: PriceData?

        for balance in balances {
            guard let priceData = prices[balance.chainAssetId] else {
                continue
            }
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
                from: balance.frozenInPlank + balance.reservedInPlank,
                precision: assetPrecision,
                rate: rate
            )

            lastPriceData = priceData
        }

        let formattedTotal = formatPrice(amount: totalPrice, priceData: lastPriceData, locale: locale)
        let formattedTransferrable = formatPrice(amount: transferrablePrice, priceData: lastPriceData, locale: locale)
        let formattedLocks = formatPrice(amount: locksPrice, priceData: lastPriceData, locale: locale)
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
        guard let priceData = prices[chainAssetId] else {
            return nil
        }
        guard let assetPrecision = chains[chainAssetId.chainId]?.asset(for: chainAssetId.assetId)?.precision else {
            return nil
        }
        let rate = Decimal(string: priceData.price) ?? 0.0

        let price = calculateAmount(
            from: plank,
            precision: assetPrecision,
            rate: rate
        )

        guard price > 0 else {
            return nil
        }

        let formattedPrice = formatPrice(amount: price, priceData: priceData, locale: locale)
        return .init(amount: formattedPrice, price: price)
    }

    private func calculateAmount(from plank: BigUInt, precision: UInt16, rate: Decimal) -> Decimal {
        let amount = Decimal.fromSubstrateAmount(
            plank,
            precision: Int16(precision)
        ) ?? 0.0
        return amount * rate
    }

    private func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}
