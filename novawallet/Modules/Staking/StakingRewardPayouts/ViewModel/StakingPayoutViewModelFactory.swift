import Foundation
import SoraFoundation
import IrohaCrypto
import UIKit

final class StakingPayoutViewModelFactory: StakingPayoutViewModelFactoryProtocol {
    private let chainFormat: ChainFormat
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let timeViewModelFactory: PayoutTimeViewModelFactoryProtocol

    init(
        chainFormat: ChainFormat,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        timeViewModelFactory: PayoutTimeViewModelFactoryProtocol
    ) {
        self.chainFormat = chainFormat
        self.balanceViewModelFactory = balanceViewModelFactory
        self.timeViewModelFactory = timeViewModelFactory
    }

    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<StakingPayoutViewModel> {
        let timerCompletion: TimeInterval?

        if let eraCountdown = eraCountdown,
           let maxPayout = payoutsInfo.payouts.max(by: { $0.era < $1.era }) {
            timerCompletion = eraCountdown.timeIntervalTillSet(
                targetEra: maxPayout.era + payoutsInfo.historyDepth + 1
            )
        } else {
            timerCompletion = nil
        }

        return LocalizableResource<StakingPayoutViewModel> { locale in
            StakingPayoutViewModel(
                cellViewModels: self.createCellViewModels(
                    for: payoutsInfo,
                    priceData: priceData,
                    eraCountdown: eraCountdown,
                    locale: locale
                ),
                eraComletionTime: timerCompletion,
                bottomButtonTitle: self.defineBottomButtonTitle(for: payoutsInfo.payouts, locale: locale)
            )
        }
    }

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<NSAttributedString> {
        let viewModelFactory = timeViewModelFactory

        return LocalizableResource { locale in
            let payout = payoutsInfo.payouts[index]
            return viewModelFactory.timeLeftAttributedString(
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale
            )
        }
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> [StakingRewardHistoryCellViewModel] {
        payoutsInfo.payouts.map { payout in
            let daysLeftText = timeViewModelFactory.timeLeftAttributedString(
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale
            )

            return StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout),
                daysLeftText: daysLeftText,
                tokenAmountText: self.tokenAmountText(payout.reward, locale: locale),
                usdAmountText: priceText(payout.reward, priceData: priceData, locale: locale)
            )
        }
    }

    private func addressTitle(_ payout: PayoutInfo) -> String {
        if let displayName = payout.identity?.displayName {
            return displayName
        }

        if let address = try? payout.validator.toAddress(using: chainFormat) {
            return address
        }

        return ""
    }

    private func tokenAmountText(_ value: Decimal, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?, locale: Locale) -> String? {
        guard let priceData = priceData else {
            return nil
        }

        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutInfo],
        locale: Locale
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.reward
            }
        let amountText = tokenAmountText(totalReward, locale: locale)
        return R.string.localizable.stakingRewardPayoutsPayoutAll(amountText, preferredLanguages: locale.rLanguages)
    }
}
