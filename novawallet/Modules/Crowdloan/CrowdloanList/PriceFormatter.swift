import Foundation
import SoraFoundation

protocol PriceFormatterProtocol {
    func balanceFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol
}

final class PriceFormatter: PriceFormatterProtocol {
    private let currencyManager: CurrencyManagerProtocol
    private let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        currencyManager: CurrencyManagerProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.currencyManager = currencyManager
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
    }

    private func priceFormatter(for priceData: PriceData?) -> LocalizableResource<TokenFormatter>? {
        guard let priceData = priceData else {
            return nil
        }

        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
        return assetFormatterFactory.createTokenFormatter(for: priceAssetInfo)
    }

    func balanceFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let localizableAmountFormatter = assetFormatterFactory.createTokenFormatter(for: targetAssetInfo)
        let localizablePriceFormatter = priceFormatter(for: priceData)

        let amountFormatter = localizableAmountFormatter.value(for: locale)
        let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

        guard
            let priceData = priceData,
            let localizablePriceFormatter = localizablePriceFormatter,
            let rate = Decimal(string: priceData.price) else {
            return BalanceViewModel(amount: amountString, price: nil)
        }

        let targetAmount = rate * amount

        let priceFormatter = localizablePriceFormatter.value(for: locale)
        let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

        return BalanceViewModel(amount: amountString, price: priceString)
    }
}
