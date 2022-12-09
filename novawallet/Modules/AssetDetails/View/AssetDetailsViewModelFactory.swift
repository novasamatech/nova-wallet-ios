import Foundation
import SoraFoundation
import BigInt

protocol AssetDetailsViewModelFactoryProtocol {
    var amountFormatter: LocalizableResource<TokenFormatter> { get }
    var priceFormatter: LocalizableResource<TokenFormatter> { get }

    func createBalanceViewModel(
        from plank: BigUInt,
        precision: UInt16,
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
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let amountFormatter: LocalizableResource<TokenFormatter>
    let priceFormatter: LocalizableResource<TokenFormatter>
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let priceChangePercentFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.amountFormatter = amountFormatter
        self.priceFormatter = priceFormatter
        self.networkViewModelFactory = networkViewModelFactory
        self.priceChangePercentFormatter = priceChangePercentFormatter
    }

    func createBalanceViewModel(
        from plank: BigUInt,
        precision: UInt16,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        balanceViewModelFactory.balanceFromPrice(
            plank.decimal(precision: precision),
            priceData: priceData
        ).value(for: locale)
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
            tokenName: asset.assetDisplayInfo.symbol,
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
        balance: AssetBalance,
        precision: UInt16,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceViewModel? {
        guard let priceData = priceData else {
            return nil
        }
        let amount = Decimal.fromSubstrateAmount(
            balance.totalInPlank,
            precision: Int16(precision)
        ) ?? 0.0
        let price = Decimal(string: priceData.price)
        let priceChangeValue = (priceData.dayChange ?? 0.0) / 100.0
        let priceChangeString = priceChangePercentFormatter.value(for: locale).stringFromDecimal(priceChangeValue) ?? ""
        let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
            ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
        let priceString = priceFormatter.value(for: locale).stringFromDecimal(price)
        return AssetPriceViewModel(amount: priceString, change: priceChange)
    }
}
