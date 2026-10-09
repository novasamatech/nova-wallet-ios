import BigInt
import Foundation

extension SubtensorStakingSetupViewModelFactory {
    static let secondsPerMonth: TimeInterval = 30 * 24 * 60 * 60

    func createSubnetDetails(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupSubnetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let sectionTitle = if case .subnetPick = input.mode {
            strings.stakingSubtensorUiPickSubnetSection()
        } else {
            strings.stakingSubtensorUiYourSubnet()
        }

        let tradePanel = createTradePanel(for: input, locale: locale)

        let card = SubtensorPickCardViewModel(
            header: createHeader(for: input, locale: locale),
            chips: createChips(for: input.subnetData.rankedSubnet, locale: locale),
            receive: createTradeRow(for: input, value: tradePanel?.receive?.amount, locale: locale),
            swapRate: createTradeRow(for: input, value: tradePanel?.swapRate, locale: locale),
            networkFee: createNetworkFee(for: input, locale: locale)
        )

        return SubtensorSetupSubnetViewModel(
            sectionTitle: sectionTitle,
            card: card,
            avgBuyPrice: createAvgBuyPrice(for: input, locale: locale),
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
            taoPrice: input.price,
            locale: locale
        )
    }

    func isQuotePending(for input: SubtensorStakingSetupViewModelInput) -> Bool {
        input.target == nil || (input.quote == nil && !input.subnetData.isQuoteFailed)
    }

    func createAvgBuyPrice(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        guard case .buyMore = input.mode else {
            return .hidden
        }

        let purchase = SubtensorPurchaseQuote(
            quote: input.quote,
            paidTao: input.amount,
            isQuotePending: isQuotePending(for: input)
        )

        return costBasisViewModelFactory.createAvgBuyPrice(
            for: input.subnetData.costBasis,
            after: purchase,
            alphaSymbol: SubtensorSubnetNaming.symbol(for: input.mode.netuid, in: input.subnetData.catalogue),
            locale: locale
        )
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
            icon: iconFactory.icon(for: catalogueSubnet, logos: subnetData.subnetLogos),
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
