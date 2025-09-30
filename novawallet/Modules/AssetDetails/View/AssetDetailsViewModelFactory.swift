import Foundation
import Foundation_iOS
import BigInt

struct AssetDetailsBalanceModelParams {
    let chain: ChainModel
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
        shouldDisplayFullInteger: Bool
    ) -> LocalizableResource<TokenFormatter>

    func priceFormatter(
        priceId: Int?,
        shouldDisplayFullInteger: Bool
    ) -> LocalizableResource<TokenFormatter>

    func createBalanceViewModel(params: AssetDetailsBalanceModelParams) -> AssetDetailsBalanceModel

    func createAssetDetailsModel(chainAsset: ChainAsset) -> AssetDetailsModel

    func createAHMInfoViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model
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
        shouldDisplayFullInteger: Bool,
        locale: Locale
    ) -> BalanceViewModel {
        let formatter = amountFormatter(
            assetDisplayInfo: assetDisplayInfo,
            shouldDisplayFullInteger: shouldDisplayFullInteger
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
            shouldDisplayFullInteger: shouldDisplayFullInteger
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
            params.total,
            params.locked,
            params.transferrable
        ].map { value in
            createBalanceModel(
                for: value,
                assetDisplayInfo: params.assetDisplayInfo,
                priceData: params.priceData,
                shouldDisplayFullInteger: false,
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

        let networkViewModel = networkViewModelFactory.createViewModel(from: params.chain)

        return AssetDetailsBalanceModel(
            chain: networkViewModel,
            total: totalModel,
            locked: lockedModel,
            transferrable: models[2]
        )
    }

    func createAssetDetailsModel(chainAsset: ChainAsset) -> AssetDetailsModel {
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: chainAsset.asset.icon)

        return AssetDetailsModel(
            tokenName: chainAsset.asset.symbol,
            assetIcon: assetIcon,
        )
    }

    func priceFormatter(
        priceId: Int?,
        shouldDisplayFullInteger: Bool
    ) -> LocalizableResource<TokenFormatter> {
        let assetBalanceDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceId)

        return assetBalanceFormatterFactory.createAssetPriceFormatter(
            for: assetBalanceDisplayInfo,
            useSuffixForBigNumbers: shouldDisplayFullInteger
        )
    }

    func amountFormatter(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        shouldDisplayFullInteger: Bool
    ) -> LocalizableResource<TokenFormatter> {
        assetBalanceFormatterFactory.createTokenFormatter(
            for: assetDisplayInfo,
            usesSuffixForBigNumbers: shouldDisplayFullInteger
        )
    }

    func createAHMInfoViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model {
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = DateFormatter
            .fullDate
            .value(for: locale)
            .string(from: date)

        let title = R.string.localizable.ahmInfoAlertAssetDetailsTitle(
            info.asset.symbol,
            info.destinationChain.name,
            preferredLanguages: languages
        )
        let message = R.string.localizable.ahmInfoAlertAssetDetailsMessage(
            formattedDate,
            info.asset.symbol,
            info.destinationChain.name,
            preferredLanguages: languages
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string.localizable.commonLearnMore(
                preferredLanguages: languages
            )
        )
        let actionTitle = R.string.localizable.ahmInfoAlertAssetDetailsAction(
            info.destinationChain.name,
            preferredLanguages: languages
        )

        return AHMAlertView.Model(
            title: title,
            message: message,
            learnMore: learnMoreModel,
            actionTitle: actionTitle
        )
    }
}
