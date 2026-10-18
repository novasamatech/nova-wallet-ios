import Foundation
import BigInt

private struct SubtensorResultTradeAmounts {
    let pay: Balance
    let receive: Balance?
}

private struct SubtensorResultTile {
    let amount: Balance?
    let isTao: Bool
    let isApproximate: Bool
}

extension SubtensorOperationResultViewModelFactory {
    func createPageViewModel(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        locale: Locale
    ) -> SubtensorResultPageViewModel {
        let request = context.request
        let direction = request.operation.tradeDirection ?? .buy
        let amounts = tradeAmounts(for: state, request: request, direction: direction)

        let payTile = createTile(
            SubtensorResultTile(amount: amounts.pay, isTao: direction == .buy, isApproximate: false),
            context: context,
            locale: locale
        )

        let receiveTile = createTile(
            SubtensorResultTile(amount: amounts.receive, isTao: direction == .sell, isApproximate: true),
            context: context,
            locale: locale
        )

        return SubtensorResultPageViewModel(
            status: createPageStatus(for: state, context: context, direction: direction, locale: locale),
            payTile: payTile,
            receiveTile: receiveTile,
            details: createDetails(for: state, context: context, amounts: amounts, locale: locale),
            action: createPageAction(for: state, locale: locale),
            showsBack: !isProgress(state)
        )
    }
}

private extension SubtensorOperationResultViewModelFactory {
    func isProgress(_ state: SubtensorOperationResultState) -> Bool {
        if case .progress = state {
            return true
        }

        return false
    }

    func tradeAmounts(
        for state: SubtensorOperationResultState,
        request: SubtensorOperationResultRequest,
        direction: SubtensorTradeDirection
    ) -> SubtensorResultTradeAmounts {
        let quotedOut = request.quote?.expectedOut

        guard case let .done(outcome, _) = state, let executed = outcome.executed else {
            return SubtensorResultTradeAmounts(pay: request.payAmount, receive: quotedOut)
        }

        switch direction {
        case .buy:
            let pay = outcome.novaFeePaid.map { executed.tao + $0 } ?? request.payAmount
            return SubtensorResultTradeAmounts(pay: pay, receive: executed.alpha)
        case .sell:
            let receive = executed.tao.subtractOrZero(outcome.novaFeePaid ?? 0)
            return SubtensorResultTradeAmounts(pay: executed.alpha, receive: receive)
        }
    }

    func createTile(
        _ tile: SubtensorResultTile,
        context: SubtensorResultViewContext,
        locale: Locale
    ) -> SwapAssetAmountViewModel {
        let request = context.request

        let subnet = context.catalogue?.subnet(for: request.target.netuid)

        let icon = tile.isTao
            ? assetIconViewModelFactory.createAssetIconViewModel(from: taoInfo)
            : subnetIconFactory.icon(for: subnet, logos: context.subnetLogos)

        guard let amount = tile.amount else {
            return SwapAssetAmountViewModel(
                imageViewModel: icon,
                hub: NetworkViewModel(name: "", icon: nil),
                amount: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown(),
                price: nil
            )
        }

        let info = tile.isTao ? taoInfo : alphaInfo(for: context)
        let amountString = formatAmount(amount, info: info, locale: locale)

        let taoAmount = tile.isTao
            ? amount
            : request.prices.alphaSpot.map { amount * $0 / SubtensorStakingPallet.alphaPriceScale }

        let fiat = taoAmount.flatMap { formatTaoFiat($0, prices: request.prices, locale: locale) }

        return SwapAssetAmountViewModel(
            imageViewModel: icon,
            hub: NetworkViewModel(name: "", icon: nil),
            amount: tile.isApproximate ? amountString.approximatelyEqual() : amountString,
            price: fiat.map { $0.approximately() }
        )
    }

    func createPageStatus(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        direction: SubtensorTradeDirection,
        locale: Locale
    ) -> SubtensorResultStatusViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch state {
        case .progress:
            let subnetName = SubtensorSubnetNaming.titleWithSymbol(
                for: context.request.target.netuid,
                in: context.catalogue,
                locale: locale
            )

            return SubtensorResultStatusViewModel(
                status: .progress,
                countdown: CountdownLoadingView.ViewModel(
                    duration: UInt(max(0, context.remainedTime).rounded(.up)),
                    units: strings.secTimeUnits()
                ),
                title: strings.swapsExecutionDontCloseApp(),
                subtitle: direction == .buy
                    ? strings.stakingSubtensorResultBuyingFormat(subnetName)
                    : strings.stakingSubtensorResultSellingFormat(subnetName),
                details: strings.commonOf("1", strings.commonOperations(format: 1))
            )
        case let .done(_, time):
            return SubtensorResultStatusViewModel(
                status: .done,
                countdown: nil,
                title: strings.transactionStatusCompleted(),
                subtitle: formatTime(time, locale: locale),
                details: strings.commonOperations(format: 1)
            )
        case let .failed(failure, time, holdRemaining):
            return SubtensorResultStatusViewModel(
                status: .failed,
                countdown: nil,
                title: strings.transactionStatusFailed(),
                subtitle: formatTime(time, locale: locale),
                details: failureDetails(
                    for: failure,
                    holdRemaining: holdRemaining,
                    request: context.request,
                    locale: locale
                )
            )
        case let .unconfirmed(time):
            return SubtensorResultStatusViewModel(
                status: .pending,
                countdown: nil,
                title: strings.commonTransactionSubmitted(),
                subtitle: formatTime(time, locale: locale),
                details: strings.stakingSubtensorResultUnconfirmedMessage()
            )
        }
    }

    func failureDetails(
        for failure: SubtensorStakingSubmissionFailure,
        holdRemaining: TimeInterval?,
        request: SubtensorOperationResultRequest,
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let reason = failureReason(for: failure, holdRemaining: holdRemaining, request: request, locale: locale)

        let spendStatement: String? = switch failure.stage {
        case .notSubmitted:
            strings.stakingSubtensorResultNothingSpent()
        case .dispatched:
            strings.stakingSubtensorResultFeeCharged()
        case .unconfirmed:
            nil
        }

        return ([reason] + [spendStatement].compactMap { $0 }).joined(separator: "\n")
    }

    func createDetails(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        amounts: SubtensorResultTradeAmounts,
        locale: Locale
    ) -> SubtensorResultDetailsViewModel {
        let request = context.request
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let direction = request.operation.tradeDirection ?? .buy
        let subnetInfo = alphaInfo(for: context)

        let swapRate = formatSwapRate(
            pay: amounts.pay,
            receive: amounts.receive,
            payInfo: direction == .buy ? taoInfo : subnetInfo,
            receiveInfo: direction == .buy ? subnetInfo : taoInfo,
            locale: locale
        ) ?? strings.stakingSubtensorUiValueUnknown()

        let slippage: String? = if request.origin == .newPosition {
            formatTolerance(request.slippage ?? SubtensorSlippageTolerance.defaultTolerance, locale: locale)
        } else {
            nil
        }

        let isDone: Bool = if case .done = state { true } else { false }

        return SubtensorResultDetailsViewModel(
            title: strings.stakingSubtensorResultPositionDetails(),
            swapRate: swapRate,
            costBasis: createCostBasis(for: state, context: context, amounts: amounts, locale: locale),
            slippage: slippage,
            validator: validatorName(for: request),
            networkFee: showsNetworkFee(in: state) ? networkFee(for: state, request: request, locale: locale) : nil,
            isExpanded: isDone
        )
    }

    func createCostBasis(
        for state: SubtensorOperationResultState,
        context: SubtensorResultViewContext,
        amounts: SubtensorResultTradeAmounts,
        locale: Locale
    ) -> SubtensorResultCostBasisViewModel? {
        let request = context.request

        guard
            case .done = state,
            let costBasis = request.costBasis,
            let direction = request.operation.tradeDirection else {
            return nil
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let settledCostBasis: SubtensorCostBasisState = costBasis == .loading ? .unavailable : costBasis

        switch direction {
        case .sell:
            let proceeds = amounts.receive.map { SubtensorSaleProceeds.quoted(alpha: amounts.pay, tao: $0) }

            return SubtensorResultCostBasisViewModel(
                title: strings.stakingSubtensorUiYouEarned(),
                value: costBasisViewModelFactory.createEarned(
                    for: settledCostBasis,
                    proceeds: proceeds ?? .unknown,
                    taoPrice: request.prices.taoPrice,
                    locale: locale
                )
            )
        case .buy:
            let purchase = amounts.receive.map { SubtensorPurchaseQuote.quoted(tao: amounts.pay, alpha: $0) }

            return SubtensorResultCostBasisViewModel(
                title: strings.stakingSubtensorUiAvgBuyPrice(),
                value: costBasisViewModelFactory.createAvgBuyPrice(
                    for: settledCostBasis,
                    after: purchase ?? .unknown,
                    alphaSymbol: SubtensorSubnetNaming.symbol(for: request.target.netuid, in: context.catalogue),
                    locale: locale
                )
            )
        }
    }

    func showsNetworkFee(in state: SubtensorOperationResultState) -> Bool {
        guard case let .failed(failure, _, _) = state else {
            return true
        }

        if case .dispatched = failure.stage {
            return true
        }

        return false
    }

    func formatSwapRate(
        pay: Balance,
        receive: Balance?,
        payInfo: AssetBalanceDisplayInfo,
        receiveInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String? {
        guard
            let receive,
            let rate = Decimal.rateFromSubstrate(
                amount1: pay,
                amount2: receive,
                precision1: payInfo.assetPrecision,
                precision2: receiveInfo.assetPrecision
            ) else {
            return nil
        }

        let payFormatter = formatterFactory.createTokenFormatter(for: payInfo).value(for: locale)
        let receiveFormatter = formatterFactory.createTokenFormatter(for: receiveInfo).value(for: locale)

        guard
            let oneIn = payFormatter.stringFromDecimal(1),
            let rateOut = receiveFormatter.stringFromDecimal(rate) else {
            return nil
        }

        return oneIn.estimatedEqual(to: rateOut)
    }

    func createPageAction(
        for state: SubtensorOperationResultState,
        locale: Locale
    ) -> SubtensorResultActionViewModel? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch state {
        case .progress:
            return nil
        case .done, .unconfirmed:
            return SubtensorResultActionViewModel(action: .done, title: strings.commonDone())
        case let .failed(failure, _, _):
            return failureAction(for: failure, locale: locale)
        }
    }
}
