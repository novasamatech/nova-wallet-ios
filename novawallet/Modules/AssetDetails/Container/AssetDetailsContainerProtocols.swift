protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        assetListObservable: AssetListModelObservable,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
