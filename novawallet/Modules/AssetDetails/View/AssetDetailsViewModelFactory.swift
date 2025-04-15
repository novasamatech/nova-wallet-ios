import Foundation
import Foundation_iOS
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
    func amountFormatter(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        shrinkBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

    func priceFormatter(
        priceId: Int?,
        shrinkBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter>

    func createBalanceViewModel(params: AssetDetailsBalanceModelParams) -> AssetDetailsBalanceModel

    func createAssetDetailsModel(chainAsset: ChainAsset) -> AssetDetailsModel
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
        shrinkBigNumbers: Bool,
        locale: Locale
    ) -> BalanceViewModel {
        let formatter = amountFormatter(
            assetDisplayInfo: assetDisplayInfo,
            shrinkBigNumbers: shrinkBigNumbers
        ).value(for: locale)

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

        let priceString = priceFormatter(
            priceId: priceData.currencyId,
            shrinkBigNumbers: shrinkBigNumbers
        )
        .value(for: locale)
        .stringFromDecimal(price * amount) ?? ""

        return BalanceViewModel(
            amount: amountString,
            price: priceString
        )
    }
}

extension AssetDetailsViewModelFactory: AssetDetailsViewModelFactoryProtocol {
    func createBalanceViewModel(params: AssetDetailsBalanceModelParams) -> AssetDetailsBalanceModel {
        let models = [
            (value: params.total, shrinkBigNumbers: false),
            (value: params.locked, shrinkBigNumbers: false),
            (value: params.transferrable, shrinkBigNumbers: false)
        ].map { pair in
            createBalanceModel(
                for: pair.value,
                assetDisplayInfo: params.assetDisplayInfo,
                priceData: params.priceData,
                shrinkBigNumbers: pair.shrinkBigNumbers,
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

    func createAssetDetailsModel(chainAsset: ChainAsset) -> AssetDetailsModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: chainAsset.asset.icon)

        return AssetDetailsModel(
            tokenName: chainAsset.asset.symbol,
            assetIcon: assetIcon,
            network: networkViewModel
        )
    }

    func priceFormatter(
        priceId: Int?,
        shrinkBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter> {
        let assetBalanceDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceId)

        return assetBalanceFormatterFactory.createAssetPriceFormatter(
            for: assetBalanceDisplayInfo,
            useSuffixForBigNumbers: shrinkBigNumbers
        )
    }

    func amountFormatter(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        shrinkBigNumbers: Bool
    ) -> LocalizableResource<TokenFormatter> {
        assetBalanceFormatterFactory.createTokenFormatter(
            for: assetDisplayInfo,
            usesSuffixForBigNumbers: shrinkBigNumbers
        )
    }
}
