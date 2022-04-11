import Foundation
import CommonWallet
import SoraFoundation

final class AssetDetailsViewModelFactory: AccountListViewModelFactoryProtocol {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let priceAsset: WalletAsset

    init(amountFormatterFactory: NumberFormatterFactoryProtocol, priceAsset: WalletAsset) {
        self.amountFormatterFactory = amountFormatterFactory
        self.priceAsset = priceAsset
    }

    private func createFormattedAmount(from decimalValue: Decimal, with amountFormatter: TokenFormatter) -> String {
        guard let amountString = amountFormatter.stringFromDecimal(decimalValue) else {
            return decimalValue.stringWithPointSeparator
        }

        return amountString
    }

    private func createBalanceViewModel(
        from amount: Decimal,
        price: Decimal,
        with amountFormatter: TokenFormatter,
        priceFormatter: TokenFormatter
    ) -> BalanceViewModel {
        let amountString = createFormattedAmount(from: amount, with: amountFormatter)
        let priceString = priceFormatter.stringFromDecimal(amount * price)

        return BalanceViewModel(amount: amountString, price: priceString)
    }

    func createAssetViewModel(
        for asset: WalletAsset,
        balance: BalanceData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> WalletViewModelProtocol? {
        let loclaizableAmountFormatter = amountFormatterFactory.createTokenFormatter(for: asset)
        let localizablePriceFormatter = amountFormatterFactory.createTokenFormatter(for: priceAsset)

        let amountFormatter = loclaizableAmountFormatter.value(for: locale)
        let priceFormatter = localizablePriceFormatter.value(for: locale)

        let balanceContext = BalanceContext(context: balance.context ?? [:])

        let priceString = priceFormatter.stringFromDecimal(balanceContext.price) ?? ""

        let priceChangeString = NumberFormatter.signedPercent.localizableResource().value(for: locale)
            .string(from: balanceContext.priceChange as NSNumber) ?? ""

        let priceChangeViewModel = balanceContext.priceChange >= 0.0 ?
            WalletPriceChangeViewModel.goingUp(displayValue: priceChangeString) :
            WalletPriceChangeViewModel.goingDown(displayValue: priceChangeString)

        let totalBalance = createBalanceViewModel(
            from: balance.balance.decimalValue,
            price: balanceContext.price,
            with: amountFormatter,
            priceFormatter: priceFormatter
        )

        let transferableBalance = createBalanceViewModel(
            from: balanceContext.available,
            price: balanceContext.price,
            with: amountFormatter,
            priceFormatter: priceFormatter
        )

        let lockedBalance = createBalanceViewModel(
            from: balanceContext.locked,
            price: balanceContext.price,
            with: amountFormatter,
            priceFormatter: priceFormatter
        )

        let infoDetailsCommand = WalletAccountInfoCommand(
            balanceContext: balanceContext,
            amountFormatter: loclaizableAmountFormatter,
            priceFormatter: localizablePriceFormatter,
            commandFactory: commandFactory,
            precision: asset.precision
        )

        return AssetDetailsViewModel(
            price: priceString,
            priceChangeViewModel: priceChangeViewModel,
            totalBalance: totalBalance,
            transferableBalance: transferableBalance,
            lockedBalance: lockedBalance,
            infoDetailsCommand: infoDetailsCommand
        )
    }
}
