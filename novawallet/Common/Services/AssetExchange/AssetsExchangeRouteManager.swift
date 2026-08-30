import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    struct AssetExchangeRouteWithCost {
        let path: AssetExchangeGraphPath
        let route: AssetExchangeRoute
        let additionalEstimatedCost: AssetsExchangePathCost

        var comparableAmountOut: Balance {
            route.quote.subtractOrZero(additionalEstimatedCost.amountInAssetOut)
        }

        var comparableAmountIn: Balance {
            route.quote + additionalEstimatedCost.amountInAssetIn
        }
    }

    let possiblePaths: [AssetExchangeGraphPath]
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let commissionPolicy: AssetExchangeCommissionPolicyProtocol?
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        possiblePaths: [AssetExchangeGraphPath],
        pathCostEstimator: AssetsExchangePathCostEstimating,
        commissionPolicy: AssetExchangeCommissionPolicyProtocol?,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.possiblePaths = possiblePaths
        self.pathCostEstimator = pathCostEstimator
        self.commissionPolicy = commissionPolicy
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createHopWrapper(
        for item: AnyAssetExchangeEdge,
        direction: AssetConversion.Direction,
        amountWrapper: CompoundOperationWrapper<Balance>,
        after prevWrapper: CompoundOperationWrapper<AssetExchangeRouteItem>?
    ) -> CompoundOperationWrapper<AssetExchangeRouteItem> {
        let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
            let amountIn = try prevRouteItem?.quote ?? amountWrapper.targetOperation.extractNoCancellableResultData()

            return item.quote(amount: amountIn, direction: direction)
        }

        if let prevWrapper {
            quoteWrapper.addDependency(wrapper: prevWrapper)
        } else {
            quoteWrapper.addDependency(wrapper: amountWrapper)
        }

        /*
         * `quoteIteration` reverses for `.buy`, so the hop quoted from the user's own amount is always
         * the one with no predecessor — the first hop of a sell and the last of a buy, which is
         * Android's `isUserInputAdjustable` rule without the index arithmetic. It also makes an
         * adjustable cap denominated in the user's own asset by construction.
         */
        let isUserInputHop = prevWrapper == nil

        let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
            let quote: Balance

            do {
                quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
            } catch let HydraExchangeTradeLimitError.exceedsPoolTradeLimit(cap) {
                throw HydraExchangeTradeLimitError.exceedsPoolTradeLimit(
                    cap?.marking(isUserInputAdjustable: isUserInputHop)
                )
            }

            let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
            let amountIn = try prevQuoteItem?.quote ?? amountWrapper.targetOperation.extractNoCancellableResultData()

            return AssetExchangeRouteItem(
                edge: item,
                amount: amountIn,
                quote: quote
            )
        }

        mappingOperation.addDependency(quoteWrapper.targetOperation)

        if prevWrapper == nil {
            mappingOperation.addDependency(amountWrapper.targetOperation)
        }

        return quoteWrapper.insertingTail(operation: mappingOperation)
    }

    private func createQuote(
        for path: AssetExchangeGraphPath,
        direction: AssetConversion.Direction,
        amountWrapper: CompoundOperationWrapper<Balance>
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            prevWrappers + [
                createHopWrapper(
                    for: item,
                    direction: direction,
                    amountWrapper: amountWrapper,
                    after: prevWrappers.last
                )
            ]
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
            let amount = try amountWrapper.targetOperation.extractNoCancellableResultData()
            let initRoute = AssetExchangeRoute(items: [], amount: amount, direction: direction)

            return try wrappers.reduce(initRoute) { route, wrapper in
                let item = try wrapper.targetOperation.extractNoCancellableResultData()

                return route.byAddingNext(item: item)
            }
        }

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }
        mappingOperation.addDependency(amountWrapper.targetOperation)

        let dependencies = wrappers.flatMap(\.allOperations) + amountWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension AssetsExchangeRouteManager {
    func fetchRoute(
        for amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let routeWithCostWrappers = possiblePaths.map { path in
            let routeWrapper = createQuote(
                for: path,
                direction: direction,
                amountWrapper: .createWithResult(amount)
            )
            let costWrapper = pathCostEstimator.costEstimationWrapper(for: path)

            return (path: path, route: routeWrapper, cost: costWrapper)
        }

        let candidatesOperation = ClosureOperation<CandidateSearch> {
            var exchangeRoutes: [AssetExchangeRouteWithCost] = []
            var tradeLimits: [AssetExchangeTradeLimitFailure] = []

            for pathWrappers in routeWithCostWrappers {
                do {
                    let route = try pathWrappers.route.targetOperation.extractNoCancellableResultData()
                    let cost = try pathWrappers.cost.targetOperation.extractNoCancellableResultData()

                    exchangeRoutes.append(
                        AssetExchangeRouteWithCost(
                            path: pathWrappers.path,
                            route: route,
                            additionalEstimatedCost: cost
                        )
                    )
                } catch {
                    let pathDescription = pathWrappers.path
                        .map { "\($0.type) \($0.origin.stringValue) -> \($0.destination.stringValue)" }
                        .joined(separator: ", ")

                    self.logger.warning("Route quoting failed for candidate path [\(pathDescription)]: \(error)")

                    if let tradeLimit = Self.tradeLimitFailure(from: error, direction: direction) {
                        tradeLimits.append(tradeLimit)
                    }
                }
            }

            return CandidateSearch(
                candidates: self.sortedCandidates(exchangeRoutes, direction: direction),
                tradeLimit: Self.selectedTradeLimit(from: tradeLimits)
            )
        }

        let dependencies = routeWithCostWrappers.flatMap { routeWithCostWrapper in
            routeWithCostWrapper.route.allOperations + routeWithCostWrapper.cost.allOperations
        }

        dependencies.forEach { candidatesOperation.addDependency($0) }

        let finalWrapper = createWinnerRouteWrapper(
            from: candidatesOperation,
            amount: amount,
            direction: direction
        )

        return finalWrapper.insertingHead(operations: dependencies + [candidatesOperation])
    }
}

private extension AssetsExchangeRouteManager {
    /// The outcome of the per-candidate pass. The trade limit is carried alongside the survivors
    /// because a dropped candidate's reason has no other way out of the pass — the search used to
    /// `compactMap` it away, and `nil` alone cannot say why nothing was found.
    struct CandidateSearch {
        let candidates: [AssetExchangeRouteWithCost]
        let tradeLimit: AssetExchangeTradeLimitFailure?
    }

    /// Turns a dropped candidate's error into a reportable failure, or `nil` when it is not a trade
    /// limit or the cap never became complete. An incomplete cap still pruned the candidate; it just
    /// has nothing to say about it.
    static func tradeLimitFailure(
        from error: Error,
        direction: AssetConversion.Direction
    ) -> AssetExchangeTradeLimitFailure? {
        guard
            case let HydraExchangeTradeLimitError.exceedsPoolTradeLimit(cap) = error,
            let cap,
            let limitedAsset = cap.limitedAsset,
            let minTradingLimit = cap.minTradingLimit,
            let isUserInputAdjustable = cap.isUserInputAdjustable
        else {
            return nil
        }

        return AssetExchangeTradeLimitFailure(
            limitedAsset: limitedAsset,
            maxGivenAmount: cap.maxGivenAmount,
            minTradingLimit: minTradingLimit,
            direction: direction,
            isUserInputAdjustable: isUserInputAdjustable
        )
    }

    /// The user asked what the most they can trade is, so among the caps that answer that question —
    /// the adjustable ones, all denominated in their own asset — the honest answer is the largest: at
    /// 95% of it that pool quotes and the swap goes through, and reporting a smaller pool's cap would
    /// talk them out of a trade that works. Ties keep the earlier candidate, matching `sortedCandidates`.
    ///
    /// Caps on intermediate hops name assets the user never typed, so they are neither comparable with
    /// each other nor actionable; they are ordered by candidate position for determinism only, and an
    /// adjustable cap always wins over them because only it can carry a button.
    static func selectedTradeLimit(
        from failures: [AssetExchangeTradeLimitFailure]
    ) -> AssetExchangeTradeLimitFailure? {
        let adjustable = failures.filter(\.isUserInputAdjustable)

        guard !adjustable.isEmpty else {
            return failures.first
        }

        return adjustable.max { $0.maxGivenAmount < $1.maxGivenAmount }
    }

    /// Signals that a single `.buy` candidate cannot serve the requested amount out, because grossing
    /// it up for the commission trips a pool trade limit and charging that commission on its un-grossed
    /// quote would hand the user less than they asked for. `createBuyRouteWrapper` is the only handler
    /// and answers it by moving on to the next candidate, so it never escapes the route search.
    ///
    /// It is deliberately not `nil`: `nil` means no route at all and is reached only once every
    /// candidate is exhausted. Any other failure of the re-quote — a timeout, a decode error,
    /// `tradeDisabled` — is a different type and keeps propagating untouched.
    ///
    /// It carries the cap that rejected the candidate because the gross-up re-quote is a pruning stage
    /// in its own right (FR-6), so a candidate dropped there was dropped for a trade-limit reason and
    /// FR-10 owes the user its cap. Without the payload the walk would reach `exhausted(with:)` holding
    /// only what the per-candidate pass collected, and a pool with abundant liquidity would be reported
    /// as having none. `nil` where the cap never became complete, exactly as in the per-candidate pass.
    enum CandidateRejection: Error {
        case cannotServeRequestedAmount(AssetExchangeTradeLimitFailure?)
    }

    /// Candidates ordered best first: descending output for `.sell`, ascending input for `.buy` — the
    /// orders the `max`/`min` this replaced expressed. Ties break on the original position, which makes
    /// the order total and so pins the head to the same candidate `max`/`min` returned: both keep the
    /// first extremal element, while `sorted(by:)` is not documented to be stable.
    func sortedCandidates(
        _ candidates: [AssetExchangeRouteWithCost],
        direction: AssetConversion.Direction
    ) -> [AssetExchangeRouteWithCost] {
        candidates
            .enumerated()
            .sorted { lhs, rhs in
                switch direction {
                case .sell:
                    let lhsValue = lhs.element.comparableAmountOut
                    let rhsValue = rhs.element.comparableAmountOut

                    guard lhsValue != rhsValue else {
                        return lhs.offset < rhs.offset
                    }

                    return lhsValue > rhsValue
                case .buy:
                    let lhsValue = lhs.element.comparableAmountIn
                    let rhsValue = rhs.element.comparableAmountIn

                    guard lhsValue != rhsValue else {
                        return lhs.offset < rhs.offset
                    }

                    return lhsValue < rhsValue
                }
            }
            .map(\.element)
    }

    func createWinnerRouteWrapper(
        from candidatesOperation: BaseOperation<CandidateSearch>,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let wrapper: CompoundOperationWrapper<AssetExchangeRoute?>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let search = try candidatesOperation.extractNoCancellableResultData()

            switch direction {
            case .sell:
                if let route = search.candidates.first?.route {
                    return .createWithResult(route)
                }

                return Self.exhausted(with: search.tradeLimit)
            case .buy:
                return self.createBuyRouteWrapper(
                    from: search.candidates,
                    amount: amount,
                    exhaustedWith: search.tradeLimit
                )
            }
        }

        wrapper.addDependency(operations: [candidatesOperation])

        return wrapper
    }

    /// What the search answers once no candidate is left: still `nil` — the unchanged "no route" that
    /// renders as "not enough liquidity" (FR-9) — unless a candidate was dropped for a reportable
    /// trade limit, in which case the cap is raised instead of being thrown away (FR-10).
    static func exhausted(
        with tradeLimit: AssetExchangeTradeLimitFailure?
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        guard let tradeLimit else {
            return .createWithResult(nil)
        }

        return .createWithError(tradeLimit)
    }

    /// Walks the sorted candidates until one of them survives the commission gross-up. The walk is
    /// lazy: the next candidate is only re-quoted once the current one has been rejected, so the common
    /// path where the best candidate serves costs exactly one gross-up re-quote.
    func createBuyRouteWrapper(
        from candidates: [AssetExchangeRouteWithCost],
        amount: Balance,
        exhaustedWith tradeLimit: AssetExchangeTradeLimitFailure?
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        guard let candidate = candidates.first else {
            return Self.exhausted(with: tradeLimit)
        }

        let grossedUpWrapper = createGrossedUpQuote(for: candidate, amount: amount)

        let wrapper: CompoundOperationWrapper<AssetExchangeRoute?>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            do {
                let route = try grossedUpWrapper.targetOperation.extractNoCancellableResultData()

                return .createWithResult(route)
            } catch let CandidateRejection.cannotServeRequestedAmount(rejectionLimit) {
                // The rejected candidate's cap joins the ones the per-candidate pass collected and is
                // ranked by the same rule, so both pruning stages answer FR-10 on the same footing.
                // `tradeLimit` stays first so that ties keep the earlier candidate, as before.
                return self.createBuyRouteWrapper(
                    from: Array(candidates.dropFirst()),
                    amount: amount,
                    exhaustedWith: Self.selectedTradeLimit(
                        from: [tradeLimit, rejectionLimit].compactMap { $0 }
                    )
                )
            }
        }

        wrapper.addDependency(wrapper: grossedUpWrapper)

        return wrapper.insertingHead(operations: grossedUpWrapper.allOperations)
    }

    /// Re-quotes one candidate at the grossed-up amount out. It never yields `nil`: a candidate the
    /// pool trade limits make unusable throws `CandidateRejection` instead, so that "try the next
    /// candidate" is never confused with "no route".
    func createGrossedUpQuote(
        for candidate: AssetExchangeRouteWithCost,
        amount: Balance
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        guard
            let commissionPolicy,
            commissionPolicy.hasChargingSite(in: candidate.path) else {
            return .createWithResult(candidate.route)
        }

        let grossedAmount = commissionPolicy.grossingUpAmountOut(amount, for: candidate.path)

        let routeWrapper = createQuote(
            for: candidate.path,
            direction: .buy,
            amountWrapper: .createWithResult(grossedAmount)
        )

        let mappingOperation = ClosureOperation<AssetExchangeRoute?> {
            let grossedRoute: AssetExchangeRoute

            do {
                grossedRoute = try routeWrapper.targetOperation.extractNoCancellableResultData()
            } catch let error as HydraExchangeTradeLimitError {
                self.logger.warning("Grossed up requote hit a pool trade limit: \(error)")

                // The candidate was quoted for exactly the requested amount out, so it only delivers
                // that amount while nothing is deducted from it. Charging the commission on it would
                // hand the user less than they asked for without ever saying so, so this candidate is
                // out and the walk moves on to the next one — carrying the cap that rejected it.
                guard commissionPolicy.resolveCommission(for: candidate.route) == nil else {
                    throw CandidateRejection.cannotServeRequestedAmount(
                        Self.tradeLimitFailure(from: error, direction: .buy)
                    )
                }

                return candidate.route
            }

            guard commissionPolicy.resolveCommission(for: grossedRoute) != nil else {
                return candidate.route
            }

            return grossedRoute
        }

        mappingOperation.addDependency(routeWrapper.targetOperation)

        return routeWrapper.insertingTail(operation: mappingOperation)
    }
}
