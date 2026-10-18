import Foundation

extension SubtensorSubnetDetailsViewModelFactory {
    static let volatilitySafeAnchor: Decimal = 0.015
    static let volatilityRiskAnchor: Decimal = 0.08
    static let secondsPerDay: TimeInterval = 24 * 60 * 60
    static let daysPerMonth = 30

    static var calmerVolatility: Decimal {
        volatilitySafeAnchor + (volatilityRiskAnchor - volatilitySafeAnchor) *
            SubtensorSubnetFactorsEvaluator.calmerVolatilityScore / 100
    }

    func createFactors(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetFactorsViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let rankedSubnet = state.rankingView?.subnet(for: subnet.netuid)

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(
                rankedSubnet: rankedSubnet,
                listedSince: listedSince(for: state.listing),
                isNotListed: state.listing == .notListed,
                now: state.now
            )
        )

        let rows = evaluation.factors.map { factor in
            createRow(for: factor, isLoading: isLoading(factor.kind, state: state), locale: locale)
        }

        guard state.isRankingLoaded, state.listing != .loading else {
            return SubtensorSubnetFactorsViewModel(heading: nil, rows: rows, footer: nil, reasons: nil, freshness: nil)
        }

        let heading = evaluation.isSafer
            ? strings.stakingSubtensorUiDetailSafer()
            : strings.stakingSubtensorUiDetailRiskier()

        return SubtensorSubnetFactorsViewModel(
            heading: heading,
            rows: rows,
            footer: strings.stakingSubtensorUiDetailFactorsFooterFormat(
                evaluation.saferCount,
                total: evaluation.factors.count
            ),
            reasons: rankedSubnet.flatMap { createReasons(for: $0, locale: locale) },
            freshness: createFreshness(for: state.rankingView, locale: locale)
        )
    }
}

private extension SubtensorSubnetDetailsViewModelFactory {
    func listedSince(for listing: SubtensorSubnetListingState) -> Date? {
        guard case let .listed(since) = listing else {
            return nil
        }

        return since
    }

    func isLoading(_ kind: SubtensorSubnetFactor.Kind, state: SubtensorSubnetDetailsState) -> Bool {
        switch kind {
        case .priceHistory:
            return state.listing == .loading
        case .age, .validators, .pool, .steadiness:
            return !state.isRankingLoaded
        }
    }

    func createRow(
        for factor: SubtensorSubnetFactor,
        isLoading: Bool,
        locale: Locale
    ) -> SubtensorSubnetFactorRowViewModel {
        let title = createTitle(for: factor.kind, locale: locale)
        let caption = createCaption(for: factor.kind, locale: locale)

        guard !isLoading else {
            return SubtensorSubnetFactorRowViewModel(title: title, caption: caption, value: .loading)
        }

        let text = createValueText(for: factor.value, locale: locale)
        let value: SubtensorSubnetFactorRowViewModel.Value

        switch factor.verdict {
        case .safer:
            value = .safer(text)
        case .riskier:
            value = .riskier(text)
        case .unknown:
            value = .unknown(text)
        }

        return SubtensorSubnetFactorRowViewModel(title: title, caption: caption, value: value)
    }

    func createTitle(for kind: SubtensorSubnetFactor.Kind, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch kind {
        case .age:
            return strings.stakingSubtensorUiPickerAge()
        case .validators:
            return strings.stakingRecommendedTitle()
        case .pool:
            return strings.stakingSubtensorUiDetailFactorPool()
        case .priceHistory:
            return strings.stakingSubtensorUiDetailFactorHistory()
        case .steadiness:
            return strings.stakingSubtensorUiDetailFactorRange()
        }
    }

    func createCaption(for kind: SubtensorSubnetFactor.Kind, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch kind {
        case .age:
            let months = Int(SubtensorSubnetFactorsEvaluator.saferAgeMonths)
            return strings.stakingSubtensorUiDetailFactorSaferAboveFormat(strings.commonMonthsFormat(format: months))
        case .validators:
            let count = formatCount(SubtensorSubnetFactorsEvaluator.saferValidatorCount, locale: locale)
            return strings.stakingSubtensorUiDetailFactorSaferAboveFormat(count)
        case .pool:
            let pool = formatCompactTao(SubtensorSubnetFactorsEvaluator.deepPoolTao, locale: locale)
            return strings.stakingSubtensorUiDetailFactorDeepAboveFormat(pool)
        case .priceHistory:
            let months = Int(SubtensorSubnetFactorsEvaluator.saferPriceHistoryMonths)
            return strings.stakingSubtensorUiDetailFactorSaferAboveFormat(strings.commonMonthsFormat(format: months))
        case .steadiness:
            let percent = formatPercent(Self.calmerVolatility, locale: locale)
            return strings.stakingSubtensorUiDetailFactorCalmerBelowFormat(percent)
        }
    }

    func createValueText(for value: SubtensorSubnetFactor.Value, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch value {
        case let .duration(seconds):
            return formatDuration(seconds, locale: locale)
        case let .count(count):
            return formatCount(count, locale: locale)
        case let .pool(poolTao, tier):
            let pool = formatCompactTao(poolTao, locale: locale)

            switch tier {
            case .deep:
                return strings.stakingSubtensorUiDetailFactorPoolDeepFormat(pool)
            case .thin:
                return strings.stakingSubtensorUiDetailFactorPoolThinFormat(pool)
            case .regular:
                return pool
            }
        case let .volatility(volatility):
            return strings.stakingSubtensorUiDetailFactorRangeFormat(formatPercent(volatility, locale: locale))
        case .notListed:
            return strings.stakingSubtensorUiDetailFactorHistoryNone()
        case .unknown:
            return unknownValue(for: locale)
        }
    }

    func formatDuration(_ seconds: TimeInterval, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let days = Int(max(seconds, 0) / Self.secondsPerDay)
        let months = days / Self.daysPerMonth

        return months > 0 ? strings.commonMonthsFormat(format: months) : strings.commonDaysFormat(format: days)
    }

    func createReasons(for rankedSubnet: SubtensorRankedSubnet, locale: Locale) -> String? {
        let isAboveThreshold = rankedSubnet.riskClass == .aboveThreshold

        guard rankedSubnet.status != .scored || !rankedSubnet.isEligible || isAboveThreshold else {
            return nil
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        var phrases = rankedSubnet.reasons.compactMap { reason in
            createReasonPhrase(for: reason, locale: locale)
        }

        if isAboveThreshold {
            phrases.append(strings.stakingSubtensorUiDetailReasonAboveThreshold())
        }

        let listFormatter = ListFormatter()
        listFormatter.locale = locale

        guard !phrases.isEmpty, let joined = listFormatter.string(from: phrases) else {
            return strings.stakingSubtensorUiDetailReasonsGeneric()
        }

        return strings.stakingSubtensorUiDetailReasonsFormat(joined)
    }

    func createReasonPhrase(for reason: String, locale: Locale) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch reason {
        case "pool_below_min":
            return strings.stakingSubtensorUiDetailReasonPoolBelowMin()
        case "subnet_too_young":
            return strings.stakingSubtensorUiDetailReasonTooYoung()
        case "not_refreshed":
            return strings.stakingSubtensorUiDetailReasonNotRefreshed()
        case "no_identity":
            return strings.stakingSubtensorUiDetailReasonNoIdentity()
        case "no_positive_signal":
            return strings.stakingSubtensorUiDetailReasonNoPositiveSignal()
        case "insufficient_history":
            return strings.stakingSubtensorUiDetailReasonInsufficientHistory()
        default:
            return nil
        }
    }

    func createFreshness(for rankingView: SubtensorRankedSubnets?, locale: Locale) -> String? {
        guard let generation = rankingView?.generation, generation.stamp.freshness == .stale else {
            return nil
        }

        let age = generation.shownAge().localizedDaysHoursOrFallbackMinutes(for: locale)

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiFreshnessUpdatedFormat(age)
    }
}
