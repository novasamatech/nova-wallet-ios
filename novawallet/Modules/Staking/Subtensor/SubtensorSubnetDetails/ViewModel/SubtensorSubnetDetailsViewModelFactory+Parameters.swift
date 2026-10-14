import Foundation

extension SubtensorSubnetDetailsViewModelFactory {
    func createParameters(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetParametersViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let parameters = state.parameters
        let split = parameters?.poolSplit
        let age = parameters?.age.flatMap { interval -> String? in
            let formatter = DateComponentsFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.calendar?.locale = locale
            formatter.allowedUnits = [.year, .month, .day, .hour, .minute]
            formatter.maximumUnitCount = 1
            formatter.unitsStyle = .full
            return formatter.string(from: interval).map { strings.stakingSubtensorV22ApproximateFormat($0) }
        }
        let tao = parameters?.subnet?.taoIn
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
                row(
                    strings.stakingSubtensorQuickPoolTitle(),
                    value: tao
                        .map { formatCompactTao($0.decimal(assetInfo: chainAsset.assetDisplayInfo), locale: locale) },
                    detail: tao
                        .flatMap {
                            fiat($0.decimal(assetInfo: chainAsset.assetDisplayInfo), state: state, locale: locale)
                        },
                    state: state,
                    locale: locale
                )
            ]
        )
    }

    func createMoreDetails(for state: SubtensorSubnetDetailsState, locale: Locale) -> [SubtensorParameterRowViewModel] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let parameters = state.parameters
        let tao = parameters?.subnet?.taoIn
        let alpha = parameters?.subnet?.alphaIn
        let alphaTao = alpha.flatMap { amount in
            parameters?.alphaPrice.map {
                amount.decimal(assetInfo: chainAsset.assetDisplayInfo) *
                    $0.decimal(assetInfo: chainAsset.assetDisplayInfo)
            }
        }
        return [
            SubtensorParameterRowViewModel(
                title: strings.stakingSubtensorV22Uid(),
                value: String(subnet.netuid),
                detail: nil
            ),
            row(
                strings.stakingSubtensorV22TaoPool(),
                value: tao.map { formatCompactTao($0.decimal(assetInfo: chainAsset.assetDisplayInfo), locale: locale) },
                detail: tao
                    .flatMap { fiat($0.decimal(assetInfo: chainAsset.assetDisplayInfo), state: state, locale: locale) },
                state: state,
                locale: locale
            ),
            row(
                strings.stakingSubtensorV22AlphaPool(),
                value: alpha.map { formatAlpha($0, locale: locale) },
                detail: alphaTao.flatMap { fiat($0, state: state, locale: locale) },
                state: state,
                locale: locale
            ),
            row(
                strings.stakingSubtensorV22Emission(),
                value: parameters?.emission.map { formatPercent($0, locale: locale) },
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

    func fiat(_ tao: Decimal, state: SubtensorSubnetDetailsState, locale: Locale) -> String? {
        state.taoPrice.map { balanceViewModelFactory.priceFromAmount(tao, priceData: $0).value(for: locale) }
    }
}
