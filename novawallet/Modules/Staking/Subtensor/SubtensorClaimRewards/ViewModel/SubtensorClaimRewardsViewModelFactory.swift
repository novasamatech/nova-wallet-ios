import Foundation

protocol SubtensorClaimViewModelFactoryProtocol {
    func createViewModel(
        for input: SubtensorClaimRewardsViewModelInput,
        locale: Locale
    ) -> SubtensorClaimRewardsViewModel

    func createMinimumClaim(_ amount: Balance, locale: Locale) -> String
}

final class SubtensorClaimRewardsViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainAsset = chainAsset
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        self.formatterFactory = formatterFactory
    }
}

private extension SubtensorClaimRewardsViewModelFactory {
    var taoInfo: AssetBalanceDisplayInfo {
        chainAsset.assetDisplayInfo
    }

    func formatTao(_ amount: Balance, roundingMode: NumberFormatter.RoundingMode, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(
            amount.decimal(assetInfo: taoInfo),
            roundingMode: roundingMode
        ).value(for: locale)
    }

    func formatDuration(blocks: UInt64, locale: Locale) -> String {
        let time = (TimeInterval(blocks) * TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)).seconds

        return time.localizedDaysHoursOrFallbackMinutes(for: locale)
    }

    func createAmount(for input: SubtensorClaimRewardsViewModelInput, locale: Locale) -> BalanceViewModelProtocol {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            input.preview.redeemable.decimal(assetInfo: taoInfo),
            priceData: input.price,
            roundingMode: .down
        ).value(for: locale)

        return BalanceViewModel(amount: viewModel.amount.approximatelyEqual(), price: viewModel.price)
    }

    func createFee(for input: SubtensorClaimRewardsViewModelInput, locale: Locale) -> BalanceViewModelProtocol? {
        input.fee.map { fee in
            balanceViewModelFactory.balanceFromPrice(
                fee.amount.decimal(assetInfo: taoInfo),
                priceData: input.price,
                roundingMode: .up
            ).value(for: locale)
        }
    }

    func createStakeAfter(for input: SubtensorClaimRewardsViewModelInput, locale: Locale) -> String? {
        guard
            let rootStake = input.rootStake,
            let beforeString = formatterFactory.createDisplayFormatter(for: taoInfo).value(for: locale)
            .stringFromDecimal(rootStake.decimal(assetInfo: taoInfo)) else {
            return nil
        }

        let afterString = formatTao(rootStake + input.preview.redeemable, roundingMode: .down, locale: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiStakeAfterFormat(
            beforeString,
            afterString.approximatelyEqual()
        )
    }

    func createNotice(for input: SubtensorClaimRewardsViewModelInput, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        var sentences = [strings.stakingSubtensorClaimRestakeHintFormat(input.validatorName)]

        if let unlockInterval = input.unlockInterval, unlockInterval > 0 {
            sentences.append(
                strings.stakingSubtensorClaimHoldHintFormat(
                    input.validatorName,
                    formatDuration(blocks: unlockInterval, locale: locale)
                )
            )
        }

        if input.preview.forfeitedEstimate > 0 {
            let forfeit = formatTao(input.preview.forfeitedEstimate, roundingMode: .up, locale: locale)

            sentences.append(strings.stakingSubtensorClaimForfeitHintFormat(forfeit))
        }

        if input.otherClaimableCount > 0 {
            sentences.append(strings.stakingSubtensorClaimOtherValidatorsHint())
        }

        return sentences.joined(separator: "\n")
    }
}

extension SubtensorClaimRewardsViewModelFactory: SubtensorClaimViewModelFactoryProtocol {
    func createViewModel(
        for input: SubtensorClaimRewardsViewModelInput,
        locale: Locale
    ) -> SubtensorClaimRewardsViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorClaimRewardsViewModel(
            amount: createAmount(for: input, locale: locale),
            networkFee: createFee(for: input, locale: locale),
            stakeAfter: createStakeAfter(for: input, locale: locale),
            notice: createNotice(for: input, locale: locale),
            signingHint: input.signing == .noSigning ? strings.accountManagementWatchOnlyHint() : nil,
            isActionEnabled: input.signing == .allowed && !input.isNothingToClaim
        )
    }

    func createMinimumClaim(_ amount: Balance, locale: Locale) -> String {
        formatTao(amount, roundingMode: .up, locale: locale)
    }
}
