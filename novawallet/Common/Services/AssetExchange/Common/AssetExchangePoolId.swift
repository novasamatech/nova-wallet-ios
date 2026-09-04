import Foundation

/**
 *  Identifies the on-chain liquidity pool an exchange edge trades through.
 *
 *  A route must not enter the same pool twice. Hydration router pre-computes every hop of a buy
 *  from the state before execution and passes the result as an exact per-hop limit, so a pool
 *  modified by an earlier hop of the same route reverts the later hop with a slippage error.
 */
struct AssetExchangePoolId: Hashable {
    let chainId: ChainModel.Id
    let identifier: String
}
