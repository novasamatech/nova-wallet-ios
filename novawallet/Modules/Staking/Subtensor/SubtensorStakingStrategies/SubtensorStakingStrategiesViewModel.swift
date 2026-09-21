import Foundation

struct SubtensorStakingStrategiesViewModel {
    let title: String
    let cards: [SubtensorStakingStrategyCardViewModel]
    let disclaimer: String
}

struct SubtensorStakingStrategyCardViewModel {
    let kind: SubtensorStakingStrategy.Kind
    let badge: String
    let title: String
    let subtitle: String
    let details: String
    let annualReturn: String
    let annualReturnTitle: String
    let annualReturnDetails: String
    let range: SubtensorStakingStrategyRangeViewModel
    let chartValues: [Double]
}

struct SubtensorStakingStrategyRangeViewModel {
    enum Style {
        case fixed
        case balanced
        case higherUpside
    }

    let style: Style
    let lowerTitle: String
    let periodTitle: String
    let upperTitle: String
}

protocol SubtensorStakingStrategiesViewModelFactoryProtocol {
    func createViewModel(
        from strategies: [SubtensorStakingStrategy],
        locale: Locale
    ) -> SubtensorStakingStrategiesViewModel
}

struct SubtensorStakingStrategiesViewModelFactory:
    SubtensorStakingStrategiesViewModelFactoryProtocol {
    func createViewModel(
        from strategies: [SubtensorStakingStrategy],
        locale: Locale
    ) -> SubtensorStakingStrategiesViewModel {
        .init(
            title: Strings.title,
            cards: strategies.map { createCardViewModel(from: $0, locale: locale) },
            disclaimer: Strings.disclaimer
        )
    }
}

private extension SubtensorStakingStrategiesViewModelFactory {
    func createCardViewModel(
        from strategy: SubtensorStakingStrategy,
        locale: Locale
    ) -> SubtensorStakingStrategyCardViewModel {
        let content = localizedContent(for: strategy.kind, locale: locale)

        return .init(
            kind: strategy.kind,
            badge: content.badge,
            title: content.title,
            subtitle: content.subtitle,
            details: content.details,
            annualReturn: formatPercent(strategy.annualReturn, locale: locale),
            annualReturnTitle: Strings.averageApy,
            annualReturnDetails: annualReturnDetails(for: strategy.kind, locale: locale),
            range: createRangeViewModel(from: strategy, locale: locale),
            chartValues: strategy.chartValues
        )
    }

    func annualReturnDetails(
        for kind: SubtensorStakingStrategy.Kind,
        locale _: Locale
    ) -> String {
        switch kind {
        case .steady:
            return Strings.steadyApyDetails
        case .balanced:
            return Strings.balancedApyDetails
        case .higherUpside:
            return Strings.upsideApyDetails
        }
    }

    func localizedContent(
        for kind: SubtensorStakingStrategy.Kind,
        locale _: Locale
    ) -> (badge: String, title: String, subtitle: String, details: String) {
        switch kind {
        case .steady:
            return (
                Strings.steadyBadge,
                Strings.steadyTitle,
                Strings.steadySubtitle,
                Strings.steadyDetails
            )
        case .balanced:
            return (
                Strings.balancedBadge,
                Strings.balancedTitle,
                Strings.balancedSubtitle,
                Strings.balancedDetails
            )
        case .higherUpside:
            return (
                Strings.upsideBadge,
                Strings.upsideTitle,
                Strings.upsideSubtitle,
                Strings.upsideDetails
            )
        }
    }

    func createRangeViewModel(
        from strategy: SubtensorStakingStrategy,
        locale: Locale
    ) -> SubtensorStakingStrategyRangeViewModel {
        let periodTitle = Strings.rangePeriod

        switch strategy.range {
        case .fixed:
            let fixedTitle = Strings.fixedRange

            return .init(
                style: .fixed,
                lowerTitle: fixedTitle,
                periodTitle: periodTitle,
                upperTitle: fixedTitle
            )
        case let .percentage(lower, upper):
            let style: SubtensorStakingStrategyRangeViewModel.Style =
                strategy.kind == .higherUpside ? .higherUpside : .balanced

            return .init(
                style: style,
                lowerTitle: formatSignedPercent(lower, locale: locale),
                periodTitle: periodTitle,
                upperTitle: formatSignedPercent(upper, locale: locale)
            )
        }
    }

    func formatPercent(_ value: Decimal, locale: Locale) -> String {
        "\(formatNumber(value * 100, locale: locale)) %"
    }

    func formatSignedPercent(_ value: Decimal, locale: Locale) -> String {
        let number = formatNumber(abs(value) * 100, locale: locale)

        if value < 0 {
            return "−\(number) %"
        }

        return "+\(number) %"
    }

    func formatNumber(_ value: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        return formatter.string(from: value as NSDecimalNumber) ?? ""
    }

    enum Strings {
        static let title = "Possible strategies"
        static let disclaimer = "Estimates at today's rates, not a forecast. Subnet tokens can fall against TAO — your initial TAO is at risk."
        static let averageApy = "avg APY"
        static let rangePeriod = "30-day range"
        static let fixedRange = "1 : 1"

        static let steadyBadge = "CALM"
        static let steadyTitle = "Steady"
        static let steadySubtitle = "Root staking"
        static let steadyDetails = "Keep your TAO as TAO. Earn a steady rate paid in TAO."
        static let steadyApyDetails = "paid in TAO · value stays 1 : 1"

        static let balancedBadge = "OUR PICK"
        static let balancedTitle = "Balanced"
        static let balancedSubtitle = "Mature subnets"
        static let balancedDetails = "Swap TAO for a subnet token, earn daily rewards and gain on its growth. Mature subnets with deep pools."
        static let balancedApyDetails = "in subnet tokens · across the top tier"

        static let upsideBadge = "MOVES MORE"
        static let upsideTitle = "Higher upside"
        static let upsideSubtitle = "Younger subnets"
        static let upsideDetails = "Swap TAO for a subnet token, earn daily rewards and gain on its growth. Younger subnets move more, both ways."
        static let upsideApyDetails = "in subnet tokens · thinner pools"
    }
}
