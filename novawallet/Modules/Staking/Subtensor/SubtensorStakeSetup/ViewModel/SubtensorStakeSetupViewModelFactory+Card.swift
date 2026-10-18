import BigInt
import Foundation

extension SubtensorStakeSetupViewModelFactory {
    static let secondsPerMonth: TimeInterval = 30 * 24 * 60 * 60
    static let saferAge: TimeInterval = 6 * secondsPerMonth
    static let deepPoolTao: Decimal = 25000
    static let calmerVolatilityScore: Decimal = 50

    func createSubnetDetails(
        for input: SubtensorStakeSetupViewModelInput,
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
            chips: input.amountState == .noTao ? [] : createChips(for: input.subnetData, locale: locale),
            receive: .trade(tradePanel?.receive?.amount, isPending: isQuotePending(for: input), locale: locale),
            swapRate: .trade(tradePanel?.swapRate, isPending: isQuotePending(for: input), locale: locale),
            networkFee: createNetworkFee(for: input, locale: locale),
            isRoot: false
        )

        return SubtensorSetupSubnetViewModel(
            sectionTitle: sectionTitle,
            card: card,
            avgBuyPrice: createAvgBuyPrice(for: input, locale: locale)
        )
    }

    func createSelection(order: SubtensorQuickPickOrder, locale: Locale) -> SubtensorSetupSelectionViewModel {
        SubtensorSetupSelectionViewModel(
            section: sectionTitle(order: order, locale: locale),
            caption: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorQuickLoading()
        )
    }

    func createFailure(for input: SubtensorStakeSetupViewModelInput, locale: Locale) -> WarningView.Model? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let tryAgain = LearnMoreViewModel(iconViewModel: nil, title: strings.commonTryAgain())

        if case .quickPick = input.mode, input.selectionFailed {
            return WarningView.Model(
                title: strings.stakingSubtensorQuickUnavailableTitle(),
                message: strings.stakingSubtensorQuickUnavailable(),
                learnMore: tryAgain
            )
        }

        guard let presetError = input.presetError else {
            return nil
        }

        let apiError = presetError as? BittensorApiError

        return WarningView.Model(
            title: strings.stakingSubtensorUiValidatorFetchFailed(),
            message: apiError?.isDeviceBound == true
                ? strings.stakingSubtensorUiValidatorFetchDeviceDetail()
                : strings.stakingSubtensorUiValidatorFetchFailedDetail(),
            learnMore: (apiError?.allowsUserRetry ?? true) ? tryAgain : nil
        )
    }

    func sectionTitle(order: SubtensorQuickPickOrder, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        switch order {
        case .poolSize: return strings.stakingSubtensorQuickFirstPool()
        case .age: return strings.stakingSubtensorQuickFirstAge()
        case .apy: return strings.stakingSubtensorQuickFirstApy()
        case .root: return strings.stakingSubtensorQuickRootSection()
        }
    }

    func createChips(for subnetData: SubtensorSetupSubnetData, locale: Locale) -> [String] {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let rankedSubnet = subnetData.rankedSubnet
        var chips: [String] = []

        let age = subnetData.blockTime.flatMap { blockTime in
            rankedSubnet?.ageBlocks.map { TimeInterval($0) * blockTime.timeInterval }
        }

        if let age, age > Self.saferAge {
            let months = Int((age / Self.secondsPerMonth).rounded(.down))
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

private extension SubtensorStakeSetupViewModelFactory {
    func createTradePanel(
        for input: SubtensorStakeSetupViewModelInput,
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

    func isQuotePending(for input: SubtensorStakeSetupViewModelInput) -> Bool {
        input.target == nil || (input.quote == nil && !input.subnetData.isQuoteFailed)
    }

    func createAvgBuyPrice(
        for input: SubtensorStakeSetupViewModelInput,
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

    func createHeader(
        for input: SubtensorStakeSetupViewModelInput,
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
