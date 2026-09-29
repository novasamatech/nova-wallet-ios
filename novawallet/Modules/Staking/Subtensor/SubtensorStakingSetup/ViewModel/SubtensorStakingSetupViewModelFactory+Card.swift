import BigInt
import Foundation

extension SubtensorStakingSetupViewModelFactory {
    static let secondsPerMonth: TimeInterval = 30 * 24 * 60 * 60

    func createSubnetDetails(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupSubnetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let sectionTitle: String
        let footer: String?

        if case .subnetPick = input.mode {
            sectionTitle = strings.stakingSubtensorUiPickSubnetSection()
            footer = strings.stakingSubtensorUiChooseMyself()
        } else {
            sectionTitle = strings.stakingSubtensorUiYourSubnet()
            footer = nil
        }

        let tradePanel = createTradePanel(for: input, locale: locale)

        let card = SubtensorPickCardViewModel(
            header: createHeader(for: input, locale: locale),
            chips: createChips(for: input.subnetData.rankedSubnet, locale: locale),
            receive: createTradeRow(for: input, value: tradePanel?.receive?.amount, locale: locale),
            swapRate: createTradeRow(for: input, value: tradePanel?.swapRate, locale: locale),
            earnPerMonth: createEarnRow(for: input, earnPerMonth: tradePanel?.earnPerMonth, locale: locale),
            networkFee: createNetworkFee(for: input, locale: locale),
            footer: footer
        )

        return SubtensorSetupSubnetViewModel(
            sectionTitle: sectionTitle,
            card: card,
            feeDisclosure: quoteViewModelFactory.novaFeeDisclosure(locale: locale)
        )
    }

    func createChips(for rankedSubnet: SubtensorRankedSubnet?, locale: Locale) -> [String] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(rankedSubnet: rankedSubnet, listedSince: nil, isNotListed: false, now: Date())
        )

        return [SubtensorSubnetFactor.Kind.age, .pool, .steadiness].compactMap { kind -> String? in
            let factor = evaluation.factor(kind)

            guard factor.verdict == .safer else {
                return nil
            }

            switch (kind, factor.value) {
            case let (.age, .duration(seconds)):
                let months = Int((seconds / Self.secondsPerMonth).rounded(.down))
                return strings.stakingSubtensorUiChipAgeMonths(format: months)
            case (.pool, _):
                return strings.stakingSubtensorUiChipDeepPool()
            case (.steadiness, _):
                return strings.stakingSubtensorUiChipSteady()
            default:
                return nil
            }
        }
    }
}

private extension SubtensorStakingSetupViewModelFactory {
    func displayTarget(for input: SubtensorStakingSetupViewModelInput) -> SubtensorStakeTarget? {
        guard case let .subnet(info, price) = input.target else {
            return input.target
        }

        var displayInfo = info
        displayInfo.tokenSymbol = Data(
            SubtensorSubnetNaming.symbol(for: info.netuid, in: input.subnetData.catalogue).utf8
        )

        return .subnet(info: displayInfo, price: price)
    }

    func createTradePanel(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorTradePanelViewModel? {
        guard let target = displayTarget(for: input) else {
            return nil
        }

        return quoteViewModelFactory.createTradePanel(
            for: input.quote,
            amountIn: input.amount,
            direction: .buy,
            target: target,
            annualRate: input.subnetData.annualRate,
            taoPrice: input.price,
            locale: locale
        )
    }

    func isQuotePending(for input: SubtensorStakingSetupViewModelInput) -> Bool {
        input.target == nil || (input.quote == nil && !input.subnetData.isQuoteFailed)
    }

    func isAnnualRatePending(for input: SubtensorStakingSetupViewModelInput) -> Bool {
        !input.subnetData.isYieldsLoaded || input.validator == .pending
    }

    func createTradeRow(
        for input: SubtensorStakingSetupViewModelInput,
        value: String?,
        locale: Locale
    ) -> SubtensorSetupRowViewModel {
        if let value {
            return .value(value.isolatedLeftToRight())
        }

        if isQuotePending(for: input) {
            return .loading
        }

        return .value(R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown())
    }

    func createEarnRow(
        for input: SubtensorStakingSetupViewModelInput,
        earnPerMonth: BalanceViewModelProtocol?,
        locale: Locale
    ) -> SubtensorSetupBalanceRowViewModel {
        guard input.subnetData.annualRate != nil else {
            return isAnnualRatePending(for: input) ? .loading : .hidden
        }

        if let earnPerMonth {
            let amount = earnPerMonth.amount.isolatedLeftToRight()

            return .value(BalanceViewModel(amount: amount, price: earnPerMonth.price))
        }

        if isQuotePending(for: input) {
            return .loading
        }

        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()

        return .value(BalanceViewModel(amount: unknown, price: nil))
    }

    func createHeader(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorPickCardHeaderViewModel? {
        let subnetData = input.subnetData

        guard subnetData.isCatalogueLoaded else {
            return nil
        }

        let netuid = input.mode.netuid
        let catalogueSubnet = subnetData.catalogue?.subnet(for: netuid)

        let apy = subnetData.annualRate.map {
            SubtensorApyFormatter.text(for: $0, style: .leading, locale: locale)
        }

        var isSelectable = false

        if case let .subnetPick(target, _) = input.mode {
            let ref = SubtensorSubnetRef(
                netuid: target.netuid,
                registeredAt: target.subnetInfo?.networkRegisteredAt ?? 0
            )

            isSelectable = subnetData.catalogue?.subnet(for: ref) != nil
        }

        return SubtensorPickCardHeaderViewModel(
            icon: iconFactory.icon(for: catalogueSubnet, config: subnetData.earnConfig),
            title: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: subnetData.catalogue, locale: locale),
            apy: apy,
            isSelectable: isSelectable
        )
    }
}

private extension String {
    func isolatedLeftToRight() -> String {
        "\u{2066}\(self)\u{2069}"
    }
}
