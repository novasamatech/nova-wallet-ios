import Foundation
import SoraFoundation
import BigInt

final class AnalyticsRewardDetailsViewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol {
    let assetInfo: AssetBalanceDisplayInfo
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var txDateFormatter = DateFormatter.txDetails

    init(
        assetInfo: AssetBalanceDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.assetInfo = assetInfo
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViweModel(
        rewardModel: AnalyticsRewardDetailsModel
    ) -> LocalizableResource<AnalyticsRewardDetailsViewModel> {
        LocalizableResource { locale in
            let formatter = self.txDateFormatter.value(for: locale)
            let date = formatter.string(from: rewardModel.date)
            let amount = self.getTokenAmountText(amount: rewardModel.amount, locale: locale)

            return AnalyticsRewardDetailsViewModel(
                eventId: rewardModel.eventId,
                date: date,
                type: rewardModel.typeText(locale: locale),
                amount: amount
            )
        }
    }

    private func getTokenAmountText(amount: BigUInt, locale: Locale) -> String {
        guard
            let tokenDecimal = Decimal.fromSubstrateAmount(amount, precision: assetInfo.assetPrecision)
        else { return "" }

        let tokenAmountText = balanceViewModelFactory
            .amountFromValue(tokenDecimal)
            .value(for: locale)
        return tokenAmountText
    }
}
