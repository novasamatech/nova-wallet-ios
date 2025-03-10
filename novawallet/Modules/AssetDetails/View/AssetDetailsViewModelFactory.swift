import Foundation
import SoraFoundation
import BigInt

struct AssetDetailsBalanceModelParams {
    let total: BigUInt
    let locked: BigUInt
    let transferrable: BigUInt
    let externalBalances: [ExternalAssetBalance]
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let priceData: PriceData?
    let locale: Locale
}

protocol AssetDetailsViewModelFactoryProtocol {
    func amountFormatter(assetDisplayInfo: AssetBalanceDisplayInfo) -> LocalizableResource<TokenFormatter>
    func priceFormatter(priceId: Int?) -> LocalizableResource<TokenFormatter>

    func createBalanceViewModel(params: AssetDetailsBalanceModelParams) -> AssetDetailsBalanceModel

    func createAssetDetailsModel(
        priceData: PriceData?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AssetDetailsModel
}

final class AssetDetailsViewModelFactory {
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.priceChangePercentFormatter = priceChangePercentFormatter
    }
}

private extension AssetDetailsViewModelFactory {
    func createBalanceModel(
        for value: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModel {
        let formatter = amountFormatter(assetDisplayInfo: assetDisplayInfo).value(for: locale)
        let amount = value.decimal(precision: UInt16(assetDisplayInfo.assetPrecision))
        let amountString = formatter.stringFromDecimal(amount) ?? ""

        guard
            let priceData = priceData,
            let price = Decimal(string: priceData.price)
        else {
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

    func createPriceState(
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceViewModel {
        let price: Decimal

        if let priceData = priceData {
            price = Decimal(string: priceData.price) ?? 0.0
        } else {
            price = 0.0
        }

        let priceChangeValue = (priceData?.dayChange ?? 0.0) / 100.0
        let priceChangeString = priceChangePercentFormatter
            .value(for: locale)
            .stringFromDecimal(priceChangeValue) ?? ""
        let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
            ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
        let priceString = priceFormatter(priceId: priceData?.currencyId)
            .value(for: locale)
            .stringFromDecimal(price) ?? ""
        return AssetPriceViewModel(amount: priceString, change: priceChange)
    }
}

extension AssetDetailsViewModelFactory: AssetDetailsViewModelFactoryProtocol {
    func createBalanceViewModel(params: AssetDetailsBalanceModelParams) -> AssetDetailsBalanceModel {
        let models = [
            params.total,
            params.locked,
            params.transferrable
        ].map { value in
            createBalanceModel(
                for: value,
                assetDisplayInfo: params.assetDisplayInfo,
                priceData: params.priceData,
                locale: params.locale
            )
        }

        let totalModel = AssetDetailsInteractiveBalanceModel(
            balance: models[0],
            interactive: params.total > 0
        )
        let lockedModel = AssetDetailsInteractiveBalanceModel(
            balance: models[1],
            interactive: params.locked > 0 || !params.externalBalances.isEmpty
        )

        return AssetDetailsBalanceModel(
            total: totalModel,
            locked: lockedModel,
            transferrable: models[2]
        )
    }

    func createAssetDetailsModel(
        priceData: PriceData?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AssetDetailsModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: chainAsset.asset.icon)
        let price = createPriceState(
            priceData: priceData,
            locale: locale
        )

        return AssetDetailsModel(
            tokenName: chainAsset.asset.symbol,
            assetIcon: assetIcon,
            price: price,
            network: networkViewModel
        )
    }

    func priceFormatter(priceId: Int?) -> LocalizableResource<TokenFormatter> {
        let assetBalanceDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceId)
        return assetBalanceFormatterFactory.createAssetPriceFormatter(for: assetBalanceDisplayInfo)
    }

    func amountFormatter(assetDisplayInfo: AssetBalanceDisplayInfo) -> LocalizableResource<TokenFormatter> {
        assetBalanceFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
    }
}
