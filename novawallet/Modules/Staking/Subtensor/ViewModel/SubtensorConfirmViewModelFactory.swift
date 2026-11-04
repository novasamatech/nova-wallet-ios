import Foundation

final class SubtensorConfirmViewModelFactory {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let quoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    let subnetIconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    let costBasisViewModelFactory: SubtensorCostBasisViewModelFactory

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
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

    func title(for model: SubtensorConfirmModel, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard model.target.isRoot else {
            return model.origin == .sell ? strings.stakingSubtensorUiReviewSale() : strings.stakingSubtensorUiReview()
        }

        switch model.origin {
        case .addStake:
            return strings.stakingSubtensorUiAddStakeRootTitle()
        case .unstake:
            return strings.stakingSubtensorUiUnstakeFromRoot()
        case .newPosition, .buyMore, .sell, .claim:
            return strings.stakingSubtensorUiStakeToRoot()
        }
    }

    func createBalance(_ amount: Balance, price: PriceData?, locale: Locale) -> BalanceViewModelProtocol {
        balanceViewModelFactory.balanceFromPrice(
            amount.decimal(assetInfo: taoInfo),
            priceData: price
        ).value(for: locale)
    }

    func createPayTile(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> BalanceViewModel {
        switch input.model.direction {
        case .buy:
            let balance = createBalance(input.model.amount, price: input.price, locale: locale)

            return BalanceViewModel(amount: balance.amount, price: balance.price?.approximately())
        case .sell:
            let alphaInfo = amountDisplayInfo(for: input.model.target, catalogue: input.catalogue)

            let amount = formatterFactory.createTokenFormatter(for: alphaInfo).value(for: locale).stringFromDecimal(
                input.model.amount.decimal(assetInfo: alphaInfo)
            ) ?? ""

            let fiat = input.latestQuote.flatMap { quote in
                let taoValue = input.model.amount * quote.quote.spotPrice / SubtensorPallet.alphaPriceScale

                return createBalance(taoValue, price: input.price, locale: locale).price
            }

            return BalanceViewModel(amount: isolatedAlpha(amount), price: fiat?.approximately())
        }
    }

    func createSaleCostBasis(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorSaleCostBasisViewModel {
        let proceeds = SubtensorSaleProceeds(
            quote: input.tradesUnavailable || input.isQuoteFailed ? nil : input.latestQuote,
            soldAlpha: input.model.amount,
            isQuotePending: !input.tradesUnavailable && !input.isQuoteFailed
        )

        return costBasisViewModelFactory.createSale(
            for: input.costBasis,
            proceeds: proceeds,
            taoPrice: input.price,
            locale: locale
        )
    }

    func createCostBasis(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorSaleCostBasisViewModel {
        guard input.model.direction == .buy else {
            return createSaleCostBasis(for: input, locale: locale)
        }

        let purchase = SubtensorPurchaseQuote(
            quote: input.tradesUnavailable || input.isQuoteFailed ? nil : input.latestQuote,
            paidTao: input.model.amount,
            isQuotePending: !input.tradesUnavailable && !input.isQuoteFailed
        )

        let avgBuyPrice = costBasisViewModelFactory.createAvgBuyPrice(
            for: input.costBasis,
            after: purchase,
            alphaSymbol: SubtensorSubnetNaming.symbol(for: input.model.target.netuid, in: input.catalogue),
            taoPrice: input.price,
            locale: locale
        )

        return SubtensorSaleCostBasisViewModel(avgBuyPrice: avgBuyPrice, earned: .hidden, isEarnedEstimated: false)
    }

    func createRemark(
        for direction: SubtensorTradeDirection,
        isProfitEstimated: Bool,
        locale: Locale
    ) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch direction {
        case .buy:
            return nil
        case .sell where isProfitEstimated:
            return strings.stakingSubtensorConfirmRemarkSellProfit()
        case .sell:
            return strings.stakingSubtensorConfirmRemarkSell()
        }
    }

    func createSwapViewModel(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorConfirmSwapViewModel {
        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
        let costBasis = createCostBasis(for: input, locale: locale)

        let panel = quoteViewModelFactory.createTradePanel(
            for: input.latestQuote,
            amountIn: input.model.amount,
            direction: input.model.direction,
            target: input.model.target,
            catalogue: input.catalogue,
            taoPrice: input.price,
            networkFee: input.fee?.amountForCurrentAccount,
            locale: locale
        )

        let receive: LoadableViewModelState<BalanceViewModel>
        let swapRate: LoadableViewModelState<String>

        if input.tradesUnavailable {
            receive = .loaded(value: BalanceViewModel(amount: unknown, price: nil))
            swapRate = .loaded(value: unknown)
        } else if let panel, let panelReceive = panel.receive {
            receive = .loaded(
                value: BalanceViewModel(
                    amount: input.model.direction == .buy ? isolatedAlpha(panelReceive.amount) : panelReceive.amount,
                    price: panelReceive.price?.approximately()
                )
            )
            swapRate = .loaded(value: isolatedAlpha(panel.swapRate))
        } else {
            receive = .loading
            swapRate = .loading
        }

        return SubtensorConfirmSwapViewModel(
            pay: createPayTile(for: input, locale: locale),
            receive: receive,
            swapRate: swapRate,
            isQuoteFailed: input.isQuoteFailed,
            avgBuyPrice: costBasis.avgBuyPrice,
            youWillEarn: costBasis.earned,
            slippage: input.model.tolerance.flatMap {
                quoteViewModelFactory.createSlippageViewModel(for: $0, locale: locale)
            },
            validatorApy: input.model.direction == .buy ? input.model.validator.annualRate.map {
                SubtensorApyFormatter.text(for: $0, style: .leading, locale: locale)
            } : nil,
            remark: createRemark(
                for: input.model.direction, isProfitEstimated: costBasis.isEarnedEstimated, locale: locale
            ),
            feeDisclosure: input.latestQuote.map {
                quoteViewModelFactory.novaFeeDisclosure(rate: $0.novaFeeRate, locale: locale)
            }
        )
    }

    private func isolatedAlpha(_ text: String) -> String {
        text.hasPrefix("\u{2066}") ? text : SubtensorSubnetNaming.isolatedLeftToRight(text)
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
            afterString
        )
    }

    func createBreakdown(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorConfirmBreakdownViewModel? {
        guard case let .unstake(unstakeModel) = input.model.mode, Set(unstakeModel.plan.hotkeys).count > 1 else {
            return nil
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let target = input.model.target
        let info = target.isRoot ? taoInfo : amountDisplayInfo(for: target, catalogue: input.catalogue)
        let formatter = formatterFactory.createTokenFormatter(for: info).value(for: locale)
        let legs = unstakeModel.plan.exits.map { ($0, true) } + unstakeModel.plan.partials.map { ($0, false) }

        return SubtensorConfirmBreakdownViewModel(
            title: strings.stakingSubtensorV22ValidatorsCount(),
            legs: legs.map { slice, isExit in
                let amount = formatter.stringFromDecimal(slice.alpha.decimal(assetInfo: info)) ?? ""
                let address = try? slice.hotkey.toAddress(using: chainAsset.chain.chainFormat)

                return SubtensorConfirmLegViewModel(
                    name: unstakeModel.validators[slice.hotkey]?.name ?? address?.mediumTruncated ?? "",
                    amount: input.model.target.isRoot ? amount : isolatedAlpha(amount),
                    detail: isExit ? strings.stakingSubtensorUiConfirmFullExit() : nil
                )
            }
        )
    }

    func createRootViewModel(
        for input: SubtensorConfirmViewModelInput,
        locale: Locale
    ) -> SubtensorConfirmRootViewModel {
        SubtensorConfirmRootViewModel(
            amount: createBalance(input.model.amount, price: input.price, locale: locale),
            stakeAfter: input.stakeChange.flatMap { createStakeAfter($0, locale: locale) },
            apy: input.model.direction == .buy
                ? SubtensorApyFormatter.text(for: input.model.validator.annualRate, style: .paidInTao, locale: locale)
                : nil
        )
    }
}

extension SubtensorConfirmViewModelFactory {
    func createViewModel(for input: SubtensorConfirmViewModelInput, locale: Locale) -> SubtensorConfirmViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let content: SubtensorConfirmContentViewModel = input.model.target.isRoot
            ? .root(createRootViewModel(for: input, locale: locale))
            : .swap(createSwapViewModel(for: input, locale: locale))

        return SubtensorConfirmViewModel(
            title: title(for: input.model, locale: locale),
            content: content,
            breakdown: createBreakdown(for: input, locale: locale),
            networkFee: balanceViewModelFactory.subtensorFee(
                input.fee, info: taoInfo, price: input.price, locale: locale
            ),
            isPriceMoved: input.isPriceMoved,
            action: SubtensorSetupActionViewModel(
                title: input.isPriceMoved ? strings.stakingSubtensorConfirmNewRate() : strings.commonConfirm(),
                isEnabled: !input.isWatchOnly
            ),
            signingHint: input.isWatchOnly ? strings.accountManagementWatchOnlyHint() : nil
        )
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
        taoInfo.subtensorAlpha(netuid: target.netuid, catalogue: catalogue)
    }
}
