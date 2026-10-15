import BigInt
import Foundation

extension SubtensorStakingSetupViewModelFactory {
    static let secondsPerMonth: TimeInterval = 30 * 24 * 60 * 60
    static let saferAgeBlocks: UInt64 = 6 * 30 * 24 * 60 * 60 * 1000 / SubtensorStakingFlowConstants.blockTimeMillis
    static let deepPoolTao: Decimal = 25000
    static let calmerVolatilityScore: Decimal = 50

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
            networkFee: createNetworkFee(for: input, locale: locale),
            hasHeaderDivider: false
        )

        return SubtensorSetupSubnetViewModel(
            sectionTitle: sectionTitle,
            card: card,
            avgBuyPrice: createAvgBuyPrice(for: input, locale: locale)
        )
    }

    func createSelection(
        for input: SubtensorStakingSetupViewModelInput,
        order: SubtensorQuickPickOrder,
        locale: Locale
    ) -> SubtensorSetupSelectionViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let message = strings.stakingSubtensorQuickUnavailable()
        let failure = input.selectionFailed ? WarningView.Model(
            title: strings.stakingSubtensorQuickUnavailableTitle(),
            message: input.selectedRef.map { "\($0.netuid) · \(message)" } ?? message,
            learnMore: LearnMoreViewModel(iconViewModel: nil, title: strings.commonTryAgain())
        ) : nil

        return SubtensorSetupSelectionViewModel(
            section: sectionTitle(order: order, locale: locale),
            caption: strings.stakingSubtensorQuickLoading(),
            failure: failure
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
        var chips: [String] = []

        if let ageBlocks = rankedSubnet?.ageBlocks, ageBlocks > Self.saferAgeBlocks {
            let ageMillis = TimeInterval(ageBlocks) * TimeInterval(SubtensorStakingFlowConstants.blockTimeMillis)
            let months = Int((ageMillis / 1000 / Self.secondsPerMonth).rounded(.down))
            chips.append(strings.stakingSubtensorUiChipAgeMonths(format: months))
        }

        if let poolTao = rankedSubnet?.taoIn, !poolTao.isNaN, poolTao > Self.deepPoolTao {
            chips.append(strings.stakingSubtensorUiChipDeepPool())
        }

        if let volatility = rankedSubnet?.volatility, volatility.raw != nil,
           volatility.normalized < Self.calmerVolatilityScore {
            chips.append(strings.stakingSubtensorUiChipSteady())
        }

        return chips
    }
}

private extension SubtensorStakingSetupViewModelFactory {
    func createTradePanel(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorTradePanelViewModel? {
        guard let target = input.target else {
            return nil
        }

        return quoteViewModelFactory.createTradePanel(
            for: input.quote,
            amountIn: input.amount,
            direction: .buy,
            target: target,
            catalogue: input.matchingCatalogue,
            taoPrice: input.price,
            networkFee: nil,
            locale: locale
        )
    }

    func isQuotePending(for input: SubtensorStakingSetupViewModelInput) -> Bool {
        input.target == nil || (input.quote == nil && !input.subnetData.isQuoteFailed)
    }

    func createAvgBuyPrice(
        for input: SubtensorStakingSetupViewModelInput,
        locale: Locale
    ) -> SubtensorRowState<SubtensorCostBasisValueViewModel> {
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
    ) -> SubtensorRowState<String> {
        if let value {
            return .value(SubtensorSubnetNaming.isolatedLeftToRight(value))
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
            isSelectable = catalogue?.subnet(for: target.subnetRef) != nil
        }

        return SubtensorPickCardHeaderViewModel(
            icon: iconFactory.icon(for: catalogueSubnet, logos: subnetData.subnetLogos),
            title: SubtensorSubnetNaming.titleWithSymbol(for: netuid, in: catalogue, locale: locale),
            isSelectable: isSelectable
        )
    }
}
