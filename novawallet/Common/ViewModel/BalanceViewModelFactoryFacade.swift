import Foundation
import Foundation_iOS

protocol BalanceViewModelFactoryFacadeProtocol {
    func priceFromAmount(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData
    ) -> LocalizableResource<String>

    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String>

    func amountFromValue(
        targetAssetInfo: AssetBalanceDisplayInfo,
        value: Decimal
    ) -> LocalizableResource<String>

    func balanceFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>

    func spendingAmountFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>

    func lockingAmountFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>

    func createBalanceInputViewModel(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol>

    func createAssetBalanceViewModel(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>
}

final class BalanceViewModelFactoryFacade {
    private let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private var balanceViewModelFactories: [AssetBalanceDisplayInfo: BalanceViewModelFactoryProtocol] = [:]

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    private func getOrCreateBalanceViewModelFactory(targetAssetInfo: AssetBalanceDisplayInfo) ->
        BalanceViewModelFactoryProtocol {
        if let balanceViewModelFactory = balanceViewModelFactories[targetAssetInfo] {
            return balanceViewModelFactory
        }
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: targetAssetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        balanceViewModelFactories[targetAssetInfo] = balanceViewModelFactory
        return balanceViewModelFactory
    }
}

extension BalanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol {
    func priceFromAmount(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData
    ) -> LocalizableResource<String> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).priceFromAmount(
            amount,
            priceData: priceData
        )
    }

    func priceFromFiatAmount(
        _ decimalValue: Decimal,
        currencyId: Int?
    ) -> LocalizableResource<String> {
        let assetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)

        return getOrCreateBalanceViewModelFactory(targetAssetInfo: assetInfo).priceFromFiatAmount(
            decimalValue,
            currencyId: currencyId
        )
    }

    func amountFromValue(
        targetAssetInfo: AssetBalanceDisplayInfo,
        value: Decimal
    ) -> LocalizableResource<String> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).amountFromValue(value)
    }

    func balanceFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).balanceFromPrice(
            amount,
            priceData: priceData
        )
    }

    func spendingAmountFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).spendingAmountFromPrice(
            amount,
            priceData: priceData
        )
    }

    func lockingAmountFromPrice(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).lockingAmountFromPrice(
            amount,
            priceData: priceData
        )
    }

    func createBalanceInputViewModel(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).createBalanceInputViewModel(amount)
    }

    func createAssetBalanceViewModel(
        targetAssetInfo: AssetBalanceDisplayInfo,
        amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        getOrCreateBalanceViewModelFactory(targetAssetInfo: targetAssetInfo).createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        )
    }
}
