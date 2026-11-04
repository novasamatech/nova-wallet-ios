import Foundation

struct AssetExchangeRouterHop: Equatable {
    let assetIn: ChainAsset
    let assetOut: ChainAsset
}

struct AssetExchangeRouterDeposit: Equatable {
    enum Side: Equatable {
        case hopIn
        case hopOut
    }

    let itemIndex: Int
    let side: Side
    let asset: ChainAsset
    let amount: Balance
}

extension AssetExchangeRoute {
    func routerAccountDeposits(slippage: BigRational) throws -> [AssetExchangeRouterDeposit] {
        try mergedRuns().flatMap { run in
            try routerAccountDeposits(in: run, slippage: slippage)
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
    ) throws -> [AssetExchangeRouterDeposit] {
        let inMultiHopRun = run.count > 1

        return try run.reduce(into: []) { deposits, index in
            guard let hop = try items[index].edge.routerAccountHop(inMultiHopRun: inMultiHopRun) else {
                return
            }

            if index == run.lowerBound {
                deposits.append(
                    AssetExchangeRouterDeposit(
                        itemIndex: index,
                        side: .hopIn,
                        asset: hop.assetIn,
                        amount: depositedAmountIn(at: index, slippage: slippage)
                    )
                )
            }

            deposits.append(
                AssetExchangeRouterDeposit(
                    itemIndex: index,
                    side: .hopOut,
                    asset: hop.assetOut,
                    amount: depositedAmountOut(at: index, isRunOutput: index == run.upperBound, slippage: slippage)
                )
            )
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
