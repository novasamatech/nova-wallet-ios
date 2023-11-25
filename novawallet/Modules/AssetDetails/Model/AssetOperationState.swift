final class AssetOperationState {
    let assetListObservable: AssetListModelObservable
    let swapCompletionClosure: SwapCompletionClosure?

    init(
        assetListObservable: AssetListModelObservable,
        swapCompletionClosure: SwapCompletionClosure?
    ) {
        self.assetListObservable = assetListObservable
        self.swapCompletionClosure = swapCompletionClosure
    }
}
