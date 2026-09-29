import Foundation

extension SubtensorSubnetDetailsViewModelFactory {
    static func maxAmount(for transferable: Balance?) -> Balance? {
        guard let transferable else {
            return nil
        }

        let amount = SubtensorAmountPolicy.maxBuyOrStake(transferable: transferable, networkFee: 0)

        return amount > 0 ? amount : nil
    }

    func estimateAmount(for chip: SubtensorSubnetAmountChip, transferable: Balance?) -> Balance? {
        switch chip {
        case let .fixed(value):
            return value.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision)
        case .max:
            return Self.maxAmount(for: transferable)
        }
    }

    func createEstimate(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetEstimateViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let chips = Self.chipAmounts.map { formatTao($0, locale: locale) } +
            [strings.commonMax().capitalized(with: locale)]

        let selectedChipIndex: Int

        switch state.amount {
        case let .fixed(value):
            selectedChipIndex = Self.chipAmounts.firstIndex(of: value) ?? 0
        case .max:
            selectedChipIndex = Self.chipAmounts.count
        }

        let hold = estimateAmount(for: state.amount, transferable: state.transferable).flatMap { amount in
            SubtensorSubnetEstimate.hold(amountTao: amount, spot: subnet.taoPerAlpha)
        }

        let holdText = hold.map { amount in
            strings.stakingSubtensorUiDetailHoldFormat(formatAlpha(amount, locale: locale).approximatelyEqual())
        }

        return SubtensorSubnetEstimateViewModel(
            chips: chips,
            selectedChipIndex: selectedChipIndex,
            isMaxEnabled: Self.maxAmount(for: state.transferable) != nil,
            hold: holdText,
            earnings: createEarnings(for: state, hold: hold, locale: locale)
        )
    }
}

private extension SubtensorSubnetDetailsViewModelFactory {
    func createEarnings(
        for state: SubtensorSubnetDetailsState,
        hold: Balance?,
        locale: Locale
    ) -> SubtensorSubnetEstimateViewModel.Earnings {
        switch state.validator {
        case .pending:
            return .loading
        case .unselected:
            return .hidden
        case let .selected(item):
            guard state.isYieldsLoaded else {
                return .loading
            }

            guard
                let hold,
                let annualRate = SubtensorSubnetEstimate.annualRate(for: item.hotkey, in: state.yields) else {
                return .hidden
            }

            let strings = R.string(preferredLanguages: locale.rLanguages).localizable
            let monthly = SubtensorSubnetEstimate.monthly(hold: hold, annualRate: annualRate)
            let amount = formatAlpha(monthly, locale: locale).approximatelyEqual()

            return .value(strings.stakingSubtensorUiDetailEarningsFormat(amount))
        }
    }
}
