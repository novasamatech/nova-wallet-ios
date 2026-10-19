import Foundation

protocol SubtensorClaimRewardsViewModelFactoryProtocol {
    func createViewModel(
        for input: SubtensorClaimRewardsViewModelInput,
        locale: Locale
    ) -> SubtensorClaimRewardsViewModel
}

final class SubtensorClaimRewardsViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
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

    func createAmount(for input: SubtensorClaimRewardsViewModelInput, locale: Locale) -> BalanceViewModelProtocol {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            input.preview.redeemable.decimal(assetInfo: taoInfo),
            priceData: input.price,
            roundingMode: .down
        ).value(for: locale)

        return BalanceViewModel(amount: viewModel.amount.approximatelyEqual(), price: viewModel.price)
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

        if let unlockTime = input.unlockTime, unlockTime > 0 {
            sentences.append(
                strings.stakingSubtensorClaimHoldHintFormat(
                    input.validatorName,
                    unlockTime.localizedDaysHoursOrFallbackMinutes(for: locale)
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

extension SubtensorClaimRewardsViewModelFactory: SubtensorClaimRewardsViewModelFactoryProtocol {
    func createViewModel(
        for input: SubtensorClaimRewardsViewModelInput,
        locale: Locale
    ) -> SubtensorClaimRewardsViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorClaimRewardsViewModel(
            amount: createAmount(for: input, locale: locale),
            networkFee: balanceViewModelFactory.subtensorFee(
                input.fee, info: taoInfo, price: input.price, locale: locale
            ),
            stakeAfter: createStakeAfter(for: input, locale: locale),
            notice: createNotice(for: input, locale: locale),
            signingHint: input.isWatchOnly ? strings.accountManagementWatchOnlyHint() : nil,
            isActionEnabled: !input.isWatchOnly && !input.isNothingToClaim
        )
    }
}
