protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        operationState: AssetOperationState
    ) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
