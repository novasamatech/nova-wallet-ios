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

    private func createQuote(
        for path: AssetExchangeGraphPath,
        direction: AssetConversion.Direction,
        amountWrapper: CompoundOperationWrapper<Balance>
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            let prevWrapper = prevWrappers.last

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

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
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

            let totalWrapper = quoteWrapper.insertingTail(operation: mappingOperation)

            return prevWrappers + [totalWrapper]
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

        let candidatesOperation = ClosureOperation<[AssetExchangeRouteWithCost]> {
            let exchangeRoutes: [AssetExchangeRouteWithCost] = routeWithCostWrappers.compactMap { pathWrappers in
                do {
                    let route = try pathWrappers.route.targetOperation.extractNoCancellableResultData()
                    let cost = try pathWrappers.cost.targetOperation.extractNoCancellableResultData()

                    return AssetExchangeRouteWithCost(
                        path: pathWrappers.path,
                        route: route,
                        additionalEstimatedCost: cost
                    )
                } catch {
                    let pathDescription = pathWrappers.path
                        .map { "\($0.type) \($0.origin.stringValue) -> \($0.destination.stringValue)" }
                        .joined(separator: ", ")

                    self.logger.warning("Route quoting failed for candidate path [\(pathDescription)]: \(error)")

                    return nil
                }
            }

            return self.sortedCandidates(exchangeRoutes, direction: direction)
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
    /// Signals that a single `.buy` candidate cannot serve the requested amount out, because grossing
    /// it up for the commission trips a pool trade limit and charging that commission on its un-grossed
    /// quote would hand the user less than they asked for. `createBuyRouteWrapper` is the only handler
    /// and answers it by moving on to the next candidate, so it never escapes the route search.
    ///
    /// It is deliberately not `nil`: `nil` means no route at all and is reached only once every
    /// candidate is exhausted. Any other failure of the re-quote — a timeout, a decode error,
    /// `tradeDisabled` — is a different type and keeps propagating untouched.
    enum CandidateRejection: Error {
        case cannotServeRequestedAmount
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
        from candidatesOperation: BaseOperation<[AssetExchangeRouteWithCost]>,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let wrapper: CompoundOperationWrapper<AssetExchangeRoute?>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let candidates = try candidatesOperation.extractNoCancellableResultData()

            switch direction {
            case .sell:
                return .createWithResult(candidates.first?.route)
            case .buy:
                return self.createBuyRouteWrapper(from: candidates, amount: amount)
            }
        }

        wrapper.addDependency(operations: [candidatesOperation])

        return wrapper
    }

    /// Walks the sorted candidates until one of them survives the commission gross-up. The walk is
    /// lazy: the next candidate is only re-quoted once the current one has been rejected, so the common
    /// path where the best candidate serves costs exactly one gross-up re-quote.
    func createBuyRouteWrapper(
        from candidates: [AssetExchangeRouteWithCost],
        amount: Balance
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        guard let candidate = candidates.first else {
            return .createWithResult(nil)
        }

        let grossedUpWrapper = createGrossedUpQuote(for: candidate, amount: amount)

        let wrapper: CompoundOperationWrapper<AssetExchangeRoute?>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            do {
                let route = try grossedUpWrapper.targetOperation.extractNoCancellableResultData()

                return .createWithResult(route)
            } catch CandidateRejection.cannotServeRequestedAmount {
                return self.createBuyRouteWrapper(
                    from: Array(candidates.dropFirst()),
                    amount: amount
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
                // out and the walk moves on to the next one.
                guard commissionPolicy.resolveCommission(for: candidate.route) == nil else {
                    throw CandidateRejection.cannotServeRequestedAmount
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
