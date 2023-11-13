protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        assetListObservable: AssetListModelObservable,
        chain: ChainModel,
        asset: AssetModel,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
