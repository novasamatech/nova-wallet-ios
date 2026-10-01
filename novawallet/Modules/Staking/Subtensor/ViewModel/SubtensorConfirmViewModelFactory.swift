import Foundation

private struct SubtensorConfirmViewModelContext {
    let origin: SubtensorOperationOrigin
    let target: SubtensorStakeTarget
    let direction: SubtensorTradeDirection
    let amount: Balance
    let annualRate: Decimal?
    let tolerance: BigRational?
    let stakeChange: SubtensorConfirmStakeChange?
    let catalogue: SubtensorSubnetCatalogue?
    let latestQuote: SubtensorTradeQuote?
    let tradesUnavailable: Bool
    let isPriceMoved: Bool
    let price: PriceData?
    let fee: ExtrinsicFeeProtocol?
    let signing: SubtensorOperationGate.Verdict
    let costBasis: SubtensorCostBasisState?
}

private extension SubtensorConfirmViewModelContext {
    init(input: SubtensorConfirmViewModelInput) {
        let model = input.model

        origin = model.origin
        target = model.target
        direction = .buy
        amount = model.amount
        annualRate = model.validator.annualRate
        tolerance = model.tolerance
        stakeChange = model.origin == .addStake ? input.stakeBefore.map { before in
            SubtensorConfirmStakeChange(before: before, after: before + model.amount, isEstimated: false)
        } : nil
        catalogue = input.catalogue
        latestQuote = input.latestQuote
        tradesUnavailable = input.tradesUnavailable
        isPriceMoved = input.isPriceMoved
        price = input.price
        fee = input.fee
        signing = input.signing
        costBasis = nil
    }

    init(input: SubtensorUnstakeConfirmViewModelInput) {
        let model = input.model

        origin = model.origin
        target = model.target
        direction = .sell
        amount = model.unstakeModel.amount
        annualRate = model.validator.annualRate
        tolerance = model.tolerance
        stakeChange = input.stakeChange
        catalogue = input.catalogue
        latestQuote = input.latestQuote
        tradesUnavailable = input.tradesUnavailable
        isPriceMoved = input.isPriceMoved
        price = input.price
        fee = input.fee
        signing = input.signing
        costBasis = input.costBasis
    }
}

final class SubtensorConfirmViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let subnetIconFactory: SubtensorSubnetIconFactoryProtocol
    let costBasisViewModelFactory: SubtensorCostBasisViewModelFactory

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        subnetIconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    ) {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        quoteViewModelFactory = SubtensorQuoteViewModelFactory(
            chainAsset: chainAsset,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        self.formatterFactory = formatterFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.subnetIconFactory = subnetIconFactory
        costBasisViewModelFactory = SubtensorCostBasisViewModelFactory(
            taoInfo: chainAsset.assetDisplayInfo,
            balanceViewModelFactory: balanceViewModelFactory
        )
    }
}

private extension SubtensorConfirmViewModelFactory {
    var taoInfo: AssetBalanceDisplayInfo {
        chainAsset.assetDisplayInfo
    }

    func title(for context: SubtensorConfirmViewModelContext, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard context.target.isRoot else {
            return context.origin == .sell ? strings.stakingSubtensorUiReviewSale() : strings.stakingSubtensorUiReview()
        }

        switch context.origin {
        case .addStake:
            return strings.stakingSubtensorUiAddStakeRootTitle()
        case .unstake:
            return strings.stakingSubtensorUiUnstakeFromRoot()
        case .newPosition, .buyMore, .sell:
            return strings.stakingSubtensorUiStakeToRoot()
        }
    }

    func displayTarget(
        for target: SubtensorStakeTarget,
        catalogue: SubtensorSubnetCatalogue?
    ) -> SubtensorStakeTarget {
        guard case let .subnet(info, price) = target else {
            return target
        }

        var displayInfo = info
        displayInfo.tokenSymbol = Data(SubtensorSubnetNaming.symbol(for: info.netuid, in: catalogue).utf8)

        return .subnet(info: displayInfo, price: price)
    }

    func createBalance(_ amount: Balance, price: PriceData?, locale: Locale) -> BalanceViewModelProtocol {
        balanceViewModelFactory.balanceFromPrice(
            amount.decimal(assetInfo: taoInfo),
            priceData: price
        ).value(for: locale)
    }

    func createFee(_ fee: Balance, price: PriceData?, locale: Locale) -> BalanceViewModelProtocol {
        balanceViewModelFactory.balanceFromPrice(
            fee.decimal(assetInfo: taoInfo),
            priceData: price,
            roundingMode: .up
        ).value(for: locale)
    }

    func createPayTile(
        for context: SubtensorConfirmViewModelContext,
        locale: Locale
    ) -> SubtensorConfirmTileViewModel {
        switch context.direction {
        case .buy:
            let balance = createBalance(context.amount, price: context.price, locale: locale)

            return SubtensorConfirmTileViewModel(amount: balance.amount, price: balance.price?.approximately())
        case .sell:
            let alphaInfo = amountDisplayInfo(for: context.target, catalogue: context.catalogue)

            let amount = formatterFactory.createTokenFormatter(for: alphaInfo).value(for: locale).stringFromDecimal(
                context.amount.decimal(assetInfo: alphaInfo)
            ) ?? ""

            let fiat = context.latestQuote.flatMap { quote in
                let taoValue = context.amount * quote.quote.spotPrice / SubtensorStakingPallet.alphaPriceScale

                return createBalance(taoValue, price: context.price, locale: locale).price
            }

            return SubtensorConfirmTileViewModel(amount: amount, price: fiat?.approximately())
        }
    }

    func createSaleCostBasis(
        for context: SubtensorConfirmViewModelContext,
        locale: Locale
    ) -> SubtensorSaleCostBasisViewModel {
        let proceeds = SubtensorSaleProceeds(
            quote: context.tradesUnavailable ? nil : context.latestQuote,
            soldAlpha: context.amount,
            isQuotePending: !context.tradesUnavailable
        )

        return costBasisViewModelFactory.createSale(
            for: context.costBasis,
            proceeds: proceeds,
            alphaSymbol: SubtensorSubnetNaming.symbol(for: context.target.netuid, in: context.catalogue),
            taoPrice: context.price,
            locale: locale
        )
    }

    func createRemark(
        for direction: SubtensorTradeDirection,
        isProfitEstimated: Bool,
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch direction {
        case .buy:
            return strings.stakingSubtensorConfirmRemarkBuy()
        case .sell where isProfitEstimated:
            return strings.stakingSubtensorConfirmRemarkSellProfit()
        case .sell:
            return strings.stakingSubtensorConfirmRemarkSell()
        }
    }

    func createSwapViewModel(
        for context: SubtensorConfirmViewModelContext,
        locale: Locale
    ) -> SubtensorConfirmSwapViewModel {
        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
        let hasRate = context.annualRate != nil
        let costBasis = createSaleCostBasis(for: context, locale: locale)

        let panel = quoteViewModelFactory.createTradePanel(
            for: context.latestQuote,
            amountIn: context.amount,
            direction: context.direction,
            target: displayTarget(for: context.target, catalogue: context.catalogue),
            annualRate: context.annualRate,
            taoPrice: context.price,
            locale: locale
        )

        let receive: LoadableViewModelState<SubtensorConfirmTileViewModel>
        let swapRate: LoadableViewModelState<String>
        let earnPerMonth: LoadableViewModelState<BalanceViewModelProtocol>?

        if context.tradesUnavailable {
            receive = .loaded(value: SubtensorConfirmTileViewModel(amount: unknown, price: nil))
            swapRate = .loaded(value: unknown)
            earnPerMonth = hasRate ? .loaded(value: BalanceViewModel(amount: unknown, price: nil)) : nil
        } else if let panel, let panelReceive = panel.receive {
            receive = .loaded(
                value: SubtensorConfirmTileViewModel(
                    amount: panelReceive.amount,
                    price: panelReceive.price?.approximately()
                )
            )
            swapRate = .loaded(value: panel.swapRate)
            earnPerMonth = panel.earnPerMonth.map { .loaded(value: $0) }
        } else {
            receive = .loading
            swapRate = .loading
            earnPerMonth = hasRate ? .loading : nil
        }

        return SubtensorConfirmSwapViewModel(
            pay: createPayTile(for: context, locale: locale),
            receive: receive,
            swapRate: swapRate,
            avgBuyPrice: costBasis.avgBuyPrice,
            youWillEarn: costBasis.earned,
            slippage: context.tolerance.flatMap {
                quoteViewModelFactory.createSlippageViewModel(for: $0, locale: locale)
            },
            validatorApy: context.annualRate.map {
                SubtensorApyFormatter.text(for: $0, style: .trailing, locale: locale)
            },
            earnPerMonth: earnPerMonth,
            remark: createRemark(for: context.direction, isProfitEstimated: costBasis.isEarnedEstimated, locale: locale)
        )
    }

    func createStakeAfter(_ change: SubtensorConfirmStakeChange, locale: Locale) -> String? {
        guard
            let beforeString = formatterFactory.createDisplayFormatter(for: taoInfo).value(for: locale)
            .stringFromDecimal(change.before.decimal(assetInfo: taoInfo)) else {
            return nil
        }

        let afterString = balanceViewModelFactory.amountFromValue(change.after.decimal(assetInfo: taoInfo)).value(
            for: locale
        )

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiStakeAfterFormat(
            beforeString,
            change.isEstimated ? afterString.approximatelyEqual() : afterString
        )
    }

    func createRootViewModel(
        for context: SubtensorConfirmViewModelContext,
        locale: Locale
    ) -> SubtensorConfirmRootViewModel {
        SubtensorConfirmRootViewModel(
            amount: createBalance(context.amount, price: context.price, locale: locale),
            stakeAfter: context.stakeChange.flatMap { createStakeAfter($0, locale: locale) },
            apy: context.annualRate.map {
                SubtensorApyFormatter.text(for: $0, style: .paidInTao, locale: locale)
            }
        )
    }

    func createViewModel(for context: SubtensorConfirmViewModelContext, locale: Locale) -> SubtensorConfirmViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let content: SubtensorConfirmContentViewModel = context.target.isRoot
            ? .root(createRootViewModel(for: context, locale: locale))
            : .swap(createSwapViewModel(for: context, locale: locale))

        return SubtensorConfirmViewModel(
            title: title(for: context, locale: locale),
            content: content,
            networkFee: context.fee.map { createFee($0.amount, price: context.price, locale: locale) },
            isPriceMoved: context.isPriceMoved,
            action: SubtensorConfirmActionViewModel(
                title: context.isPriceMoved ? strings.stakingSubtensorConfirmNewRate() : strings.commonConfirm(),
                isEnabled: context.signing == .allowed
            ),
            signingHint: context.signing == .noSigning ? strings.accountManagementWatchOnlyHint() : nil
        )
    }
}

extension SubtensorConfirmViewModelFactory: SubtensorConfirmViewModelFactoryProtocol {
    func createViewModel(for input: SubtensorConfirmViewModelInput, locale: Locale) -> SubtensorConfirmViewModel {
        createViewModel(for: SubtensorConfirmViewModelContext(input: input), locale: locale)
    }

    func createViewModel(
        for input: SubtensorUnstakeConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorConfirmViewModel {
        createViewModel(for: SubtensorConfirmViewModelContext(input: input), locale: locale)
    }

    func createTileIcons(
        for target: SubtensorStakeTarget,
        direction: SubtensorTradeDirection,
        catalogue: SubtensorSubnetCatalogue?,
        subnetLogos: SubtensorSubnetLogos?
    ) -> SubtensorConfirmTileIconsViewModel {
        let taoIcon = assetIconViewModelFactory.createAssetIconViewModel(from: taoInfo)
        let alphaIcon = target.isRoot
            ? nil
            : subnetIconFactory.icon(for: catalogue?.subnet(for: target.netuid), logos: subnetLogos)

        switch direction {
        case .buy:
            return SubtensorConfirmTileIconsViewModel(pay: taoIcon, receive: alphaIcon)
        case .sell:
            return SubtensorConfirmTileIconsViewModel(pay: alphaIcon, receive: taoIcon)
        }
    }

    func amountDisplayInfo(
        for target: SubtensorStakeTarget,
        catalogue: SubtensorSubnetCatalogue?
    ) -> AssetBalanceDisplayInfo {
        displayTarget(for: target, catalogue: catalogue).assetDisplayInfo(basedOn: taoInfo)
    }
}
