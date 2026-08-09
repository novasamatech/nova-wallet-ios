import Foundation

struct AssetExchangeCommission: Equatable {
    /// Index into the atomic-operation array produced by `prepareAtomicOperations`. Counts a
    /// maximal run of consecutive `.hydraSwap` edges as ONE operation and every other edge as one.
    /// This is NOT an index into `AssetExchangeRoute.items`.
    let chargingOperationIndex: Int

    /// Asset the commission is denominated in: the charging operation's `assetOut`, which is the
    /// destination of the LAST edge of the charging run, not the first.
    let asset: ChainAssetId

    /// Fee-time estimate. Gates the skip decision and drives nothing that is signed. The submitted
    /// transfer is sized from `rate` at call-build time.
    let estimatedAmount: Balance

    let beneficiary: AccountId

    /// The rate. This is the value the submitted transfer is sized from, and the value shown.
    let rate: BigRational
}
