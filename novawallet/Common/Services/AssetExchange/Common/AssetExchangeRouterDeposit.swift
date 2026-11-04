import Foundation

struct AssetExchangeRouterDeposit: Equatable {
    let assetId: ChainAssetId
    let amount: Balance
}

struct AssetExchangeRouterHopDeposits: Equatable {
    var hopIn: AssetExchangeRouterDeposit?
    var hopOut: AssetExchangeRouterDeposit?
}

extension AssetExchangeRoute {
    func routerAccountDeposits(slippage: BigRational) throws -> [AssetExchangeRouterHopDeposits] {
        try mergedRuns().flatMap { run in
            routerAccountDeposits(in: run, slippage: slippage)
        }
    }
}

private extension AssetExchangeRoute {
    func mergedRuns() throws -> [ClosedRange<Int>] {
        let operationIndexByItem = try AssetExchangeMetaOperationFactory().createMetaOperations(for: self).indexByEdge

        return items.indices.reduce(into: []) { runs, index in
            if let lastRun = runs.last, operationIndexByItem[lastRun.upperBound] == operationIndexByItem[index] {
                runs[runs.count - 1] = lastRun.lowerBound ... index
            } else {
                runs.append(index ... index)
            }
        }
    }

    func routerAccountDeposits(
        in run: ClosedRange<Int>,
        slippage: BigRational
    ) -> [AssetExchangeRouterHopDeposits] {
        let inMultiHopRun = run.count > 1

        return run.map { index in
            var deposits = AssetExchangeRouterHopDeposits()
            let edge = items[index].edge

            guard edge.usesRouterAccount(inMultiHopRun: inMultiHopRun) else {
                return deposits
            }

            if index == run.lowerBound {
                deposits.hopIn = AssetExchangeRouterDeposit(
                    assetId: edge.origin,
                    amount: depositedAmountIn(at: index, slippage: slippage)
                )
            }

            // the intermediate ED validation owns the output of a run that feeds a later operation
            if index < run.upperBound || index == items.count - 1 {
                deposits.hopOut = AssetExchangeRouterDeposit(
                    assetId: edge.destination,
                    amount: depositedAmountOut(at: index, isRunOutput: index == run.upperBound, slippage: slippage)
                )
            }

            return deposits
        }
    }

    func depositedAmountIn(at index: Int, slippage: BigRational) -> Balance {
        let item = items[index]

        switch direction {
        case .sell:
            return index == 0 ? item.amount : item.amount.subtractOrZero(slippage.mul(value: item.amount))
        case .buy:
            return item.quote
        }
    }

    func depositedAmountOut(at index: Int, isRunOutput: Bool, slippage: BigRational) -> Balance {
        let item = items[index]

        switch direction {
        case .sell:
            // the router enforces the slippage minimum on the run output only
            return isRunOutput ? item.quote.subtractOrZero(slippage.mul(value: item.quote)) : item.quote
        case .buy:
            return item.amount
        }
    }
}
