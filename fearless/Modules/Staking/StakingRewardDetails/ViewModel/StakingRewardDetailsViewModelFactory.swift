import Foundation
import IrohaCrypto
import SoraFoundation
import FearlessUtils

protocol StakingRewardDetailsViewModelFactoryProtocol {
    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?
    ) -> LocalizableResource<StakingRewardDetailsViewModel>

    func validatorAddress(from data: Data) -> AccountAddress?
}

final class StakingRewardDetailsViewModelFactory: StakingRewardDetailsViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let iconGenerator: IconGenerating
    private let chainFormat: ChainFormat

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating,
        chainFormat: ChainFormat
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
        self.chainFormat = chainFormat
    }

    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?
    ) -> LocalizableResource<StakingRewardDetailsViewModel> {
        LocalizableResource { locale in
            let rows: [RewardDetailsRow] = [
                .validatorInfo(.init(
                    title: R.string.localizable.stakingRewardDetailsValidator(preferredLanguages: locale.rLanguages),
                    address: self.validatorAddress(from: input.payoutInfo.validator) ?? "",
                    name: self.displayName(payoutInfo: input.payoutInfo),
                    icon: self.getValidatorIcon(validatorAccount: input.payoutInfo.validator)
                )),
                .date(.init(
                    titleText: R.string.localizable.stakingRewardDetailsDate(preferredLanguages: locale.rLanguages),
                    valueText: self.formattedDateText(
                        activeEra: input.activeEra,
                        payoutEra: input.payoutInfo.era,
                        erasPerDay: input.erasPerDay
                    )
                )),
                .era(.init(
                    titleText: R.string.localizable.stakingRewardDetailsEra(preferredLanguages: locale.rLanguages),
                    valueText: "#\(input.payoutInfo.era.description)"
                )),
                .reward(.init(
                    title: R.string.localizable
                        .stakingRewardDetailsReward(preferredLanguages: locale.rLanguages),
                    tokenAmountText: self.tokenAmountText(payoutInfo: input.payoutInfo, locale: locale),
                    usdAmountText: self.priceText(payoutInfo: input.payoutInfo, priceData: priceData, locale: locale)
                ))
            ]
            return StakingRewardDetailsViewModel(rows: rows)
        }
    }

    func validatorAddress(from data: Data) -> AccountAddress? {
        try? data.toAddress(using: chainFormat)
    }

    private func displayName(payoutInfo: PayoutInfo) -> String {
        if let displayName = payoutInfo.identity?.displayName {
            return displayName
        }

        if let address = validatorAddress(from: payoutInfo.validator) {
            return address
        }
        return ""
    }

    private func tokenAmountText(payoutInfo: PayoutInfo, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(payoutInfo.reward).value(for: locale)
    }

    private func priceText(payoutInfo: PayoutInfo, priceData: PriceData?, locale: Locale) -> String {
        guard let priceData = priceData else {
            return ""
        }

        let price = balanceViewModelFactory
            .priceFromAmount(payoutInfo.reward, priceData: priceData).value(for: locale)
        return price
    }

    private func formattedDateText(
        activeEra: EraIndex,
        payoutEra: EraIndex,
        erasPerDay: UInt32
    ) -> String {
        let pastDays = erasPerDay > 0 ? (activeEra - payoutEra) / erasPerDay : 0
        guard let daysAgo = Calendar.current
            .date(byAdding: .day, value: -Int(pastDays), to: Date())
        else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        return dateFormatter.string(from: daysAgo)
    }

    private func getValidatorIcon(validatorAccount: Data) -> UIImage? {
        guard let address = validatorAddress(from: validatorAccount)
        else { return nil }
        return try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                .white,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
    }
}
