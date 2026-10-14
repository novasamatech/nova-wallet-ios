import BigInt
import Foundation

extension SubtensorStakingSetupViewModelFactory {
    static let secondsPerMonth: TimeInterval = 30 * 24 * 60 * 60

    func createSubnetDetails(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorSetupSubnetViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let sectionTitle = if let order = input.quickPickOrder {
            sectionTitle(order: order, locale: locale)
        } else if case .subnetPick = input.mode {
            strings.stakingSubtensorUiPickSubnetSection()
        } else {
            strings.stakingSubtensorUiYourSubnet()
        }

        let tradePanel = createTradePanel(for: input, locale: locale)

        let card = SubtensorPickCardViewModel(
            validator: createValidator(for: input, locale: locale),
            validatorRate: input.subnetData.annualRate.map {
                SubtensorApyFormatter.text(for: $0, style: .leading, locale: locale)
            },
            isValidatorEditable: !input.mode.isLocked,
            browseTitle: input.mode.isLocked ? nil : strings.stakingSubtensorQuickSeeAll(),
            header: createHeader(for: input, locale: locale),
            chips: input.amountState == .noTao ? [] : createChips(for: input.subnetData.rankedSubnet, locale: locale),
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

    func sectionTitle(order: SubtensorQuickPickOrder, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        switch order {
        case .poolSize: return strings.stakingSubtensorQuickFirstPool()
        case .age: return strings.stakingSubtensorQuickFirstAge()
        case .apy: return strings.stakingSubtensorQuickApyUnavailable()
        case .root: return strings.stakingSubtensorQuickRootSection()
        }
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
            SubtensorSubnetNaming.symbol(for: info.netuid, in: input.matchingCatalogue).utf8
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
        guard case let .buyMore(position) = input.mode else {
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
            alphaSymbol: SubtensorSubnetNaming.symbol(for: position.netuid, in: input.matchingCatalogue),
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
        let catalogue = input.matchingCatalogue

        guard let netuid = input.mode.netuid, input.target != nil else {
            return nil
        }

        let catalogueSubnet = catalogue?.subnet(for: netuid)

        var isSelectable = false

        if case let .subnetPick(target, _) = input.mode {
            let ref = SubtensorSubnetRef(
                netuid: target.netuid,
                registeredAt: target.subnetInfo?.networkRegisteredAt ?? 0
            )

            isSelectable = catalogue?.subnet(for: ref) != nil
        }

        return SubtensorPickCardHeaderViewModel(
            icon: iconFactory.icon(for: catalogueSubnet, logos: subnetData.subnetLogos),
            title: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: locale),
            apy: nil,
            isSelectable: isSelectable
        )
    }
}

private extension String {
    func isolatedLeftToRight() -> String {
        "\u{2066}\(self)\u{2069}"
    }
}
