import Foundation
import SoraFoundation
import BigInt

protocol AssetDetailsViewModelFactoryProtocol {
    func amountFormatter(assetDisplayInfo: AssetBalanceDisplayInfo) -> LocalizableResource<TokenFormatter>
    func priceFormatter(priceId: Int?) -> LocalizableResource<TokenFormatter>

    func createBalanceViewModel(
        value: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol

    func createAssetDetailsModel(
        balance: AssetBalance,
        priceData: PriceData?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AssetDetailsModel
}

final class AssetDetailsViewModelFactory: AssetDetailsViewModelFactoryProtocol {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.priceChangePercentFormatter = priceChangePercentFormatter
    }

    func createBalanceViewModel(
        value: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let formatter = amountFormatter(assetDisplayInfo: assetDisplayInfo).value(for: locale)
        let amount = value.decimal(precision: UInt16(assetDisplayInfo.assetPrecision))
        let amountString = formatter.stringFromDecimal(amount) ?? ""
        guard let priceData = priceData, let price = Decimal(string: priceData.price) else {
            return BalanceViewModel(
                amount: amountString,
                price: ""
            )
        }
        let priceString = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(price * amount) ?? ""
        return BalanceViewModel(
            amount: amountString,
            price: priceString
        )
    }

    func createAssetDetailsModel(
        balance: AssetBalance,
        priceData: PriceData?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AssetDetailsModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon = chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) }
        return AssetDetailsModel(
            tokenName: chainAsset.asset.symbol,
            assetIcon: assetIcon,
            price: createPriceState(
                balance: balance,
                precision: chainAsset.asset.precision,
                priceData: priceData,
                locale: locale
            ),
            network: networkViewModel
        )
    }

    private func createPriceState(
        balance _: AssetBalance,
        precision _: UInt16,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceViewModel? {
        guard let priceData = priceData,
              let price = Decimal(string: priceData.price) else {
            return nil
        }

        let priceChangeValue = (priceData.dayChange ?? 0.0) / 100.0
        let priceChangeString = priceChangePercentFormatter.value(for: locale).stringFromDecimal(priceChangeValue) ?? ""
        let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
            ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
        let priceString = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(price) ?? ""
        return AssetPriceViewModel(amount: priceString, change: priceChange)
    }

    func priceFormatter(priceId: Int?) -> LocalizableResource<TokenFormatter> {
        let assetBalanceDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceId)
        return assetBalanceFormatterFactory.createTokenFormatter(for: assetBalanceDisplayInfo)
    }

    func amountFormatter(assetDisplayInfo: AssetBalanceDisplayInfo) -> LocalizableResource<TokenFormatter> {
        assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
    }
}
