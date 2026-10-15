import Foundation

extension SubtensorSubnetDetailsViewModelFactory {
    func createParameters(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetParametersViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let parameters = state.parameters
        let pool = subnet.taoReserve + subnet.alphaReserve
        let split = pool > 0 ? BigRational(numerator: subnet.taoReserve, denominator: pool).decimalValue : nil
        let age = parameters?.age.flatMap { interval -> String? in
            let formatter = DateComponentsFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.calendar?.locale = locale
            formatter.allowedUnits = [.year, .month, .day, .hour, .minute]
            formatter.maximumUnitCount = 1
            formatter.unitsStyle = .full
            return formatter.string(from: interval).map { strings.stakingSubtensorV22ApproximateFormat($0) }
        }
        return SubtensorSubnetParametersViewModel(
            split: split,
            taoShare: strings.stakingSubtensorV22PoolShareFormat(
                strings.stakingSubtensorV22TaoPool(),
                split.map { formatPercent($0, locale: locale) } ?? unknownValue(for: locale)
            ),
            alphaShare: strings.stakingSubtensorV22PoolShareFormat(
                strings.stakingSubtensorV22AlphaPool(),
                split.map { formatPercent(1 - $0, locale: locale) } ?? unknownValue(for: locale)
            ),
            rows: [
                row(strings.stakingSubtensorUiPickerAge(), value: age, state: state, locale: locale),
                row(
                    strings.stakingSubtensorV22ValidatorsCount(),
                    value: parameters?.validators.map { formatCount($0, locale: locale) },
                    state: state,
                    locale: locale
                ),
                taoPoolRow(strings.stakingSubtensorQuickPoolTitle(), state: state, locale: locale)
            ]
        )
    }

    func createMoreDetails(for state: SubtensorSubnetDetailsState, locale: Locale) -> [SubtensorParameterRowViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let alphaTao = subnet.alphaReserve * subnet.taoPerAlpha / SubtensorStakingPallet.alphaPriceScale
        return [
            SubtensorParameterRowViewModel(
                title: strings.stakingSubtensorV22Uid(),
                value: String(subnet.netuid),
                detail: nil
            ),
            taoPoolRow(strings.stakingSubtensorV22TaoPool(), state: state, locale: locale),
            SubtensorParameterRowViewModel(
                title: strings.stakingSubtensorV22AlphaPool(),
                value: formatAlpha(subnet.alphaReserve, locale: locale),
                detail: fiat(alphaTao.decimal(assetInfo: chainAsset.assetDisplayInfo), state: state, locale: locale)
            ),
            row(
                strings.stakingSubtensorV22Emission(),
                value: state.parameters?.emission.map { formatPercent($0, locale: locale) },
                state: state,
                locale: locale
            )
        ]
    }
}

private extension SubtensorSubnetDetailsViewModelFactory {
    func row(
        _ title: String, value: String?, detail: String? = nil,
        state: SubtensorSubnetDetailsState, locale: Locale
    ) -> SubtensorParameterRowViewModel {
        SubtensorParameterRowViewModel(
            title: title, value: state.isParametersLoaded ? value ?? unknownValue(for: locale) : nil, detail: detail
        )
    }

    func taoPoolRow(
        _ title: String, state: SubtensorSubnetDetailsState, locale: Locale
    ) -> SubtensorParameterRowViewModel {
        let tao = subnet.taoReserve.decimal(assetInfo: chainAsset.assetDisplayInfo)
        return SubtensorParameterRowViewModel(
            title: title, value: formatCompactTao(tao, locale: locale), detail: fiat(tao, state: state, locale: locale)
        )
    }

    func fiat(_ tao: Decimal, state: SubtensorSubnetDetailsState, locale: Locale) -> String? {
        state.taoPrice.map { balanceViewModelFactory.priceFromAmount(tao, priceData: $0).value(for: locale) }
    }
}
