import Foundation
import SoraFoundation
import IrohaCrypto
import CommonWallet
import BigInt

protocol BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>
    func amountFromValue(_ value: Decimal) -> LocalizableResource<String>
    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func spendingAmountFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func lockingAmountFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol>
    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?)
        -> LocalizableResource<AssetBalanceViewModelProtocol>
}

protocol PriceAssetInfoFactoryProtocol {
    func createAssetBalanceDisplayInfo(from currencyId: Int) -> AssetBalanceDisplayInfo
}

final class PriceAssetInfoFactory: PriceAssetInfoFactoryProtocol {
    private let currencyManager: CurrencyManagerProtocol

    init(currencyManager: CurrencyManagerProtocol) {
        self.currencyManager = currencyManager
    }

    func createAssetBalanceDisplayInfo(from currencyId: Int) -> AssetBalanceDisplayInfo {
        guard let currency = currencyManager.availableCurrencies.first(where: { $0.id == currencyId }) else {
            assertionFailure("Currency with id: \(currencyId) not found")
            return .usd()
        }
        return .from(currency: currency)
    }
}

final class BalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let limit: Decimal

    private let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = StakingConstants.maxAmount
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.formatterFactory = formatterFactory
        self.limit = limit
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price),
              let localizableFormatter = priceFormatter(for: priceData) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount

        return LocalizableResource { locale in
            let formatter = localizableFormatter?.value(for: locale)
            return formatter?.stringFromDecimal(targetAmount) ?? ""
        }
    }

    private func priceFormatter(for priceData: PriceData?) -> LocalizableResource<TokenFormatter>? {
        guard let priceData = priceData else {
            return nil
        }

        let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
        return formatterFactory.createTokenFormatter(for: priceAssetInfo)
    }

    func amountFromValue(_ value: Decimal) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(value) ?? ""
        }
    }

    func lockingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createInputTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter?.value(for: locale)
            let priceString = priceFormatter?.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter?.value(for: locale)
            let priceString = priceFormatter?.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func spendingAmountFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    )
        -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createInputTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let optAmountString = amountFormatter.stringFromDecimal(amount)
            let amountString = optAmountString.map { "−" + $0 } ?? ""

            guard
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter?.value(for: locale)
            let priceString = priceFormatter?.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func createBalanceInputViewModel(
        _ amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol> {
        let localizableFormatter = formatterFactory.createInputFormatter(for: targetAssetInfo)
        let symbol = targetAssetInfo.symbol

        let currentLimit = limit

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return AmountInputViewModel(
                symbol: symbol,
                amount: amount,
                limit: currentLimit,
                formatter: formatter,
                precision: Int16(formatter.maximumFractionDigits)
            )
        }
    }

    func createAssetBalanceViewModel(
        _ amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let optLocalizablePriceFormatter = priceFormatter(for: priceData)

        let symbol = targetAssetInfo.symbol

        let iconViewModel = targetAssetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let priceString: String?

            if
                let priceData = priceData,
                let localizablePriceFormatter = optLocalizablePriceFormatter,
                let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount

                let priceFormatter = localizablePriceFormatter?.value(for: locale)
                priceString = priceFormatter?.stringFromDecimal(targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            let balanceString: String?

            if let balance = balance {
                balanceString = balanceFormatter.stringFromDecimal(balance)
            } else {
                balanceString = nil
            }

            return AssetBalanceViewModel(
                symbol: symbol,
                balance: balanceString,
                price: priceString,
                iconViewModel: iconViewModel
            )
        }
    }
}
