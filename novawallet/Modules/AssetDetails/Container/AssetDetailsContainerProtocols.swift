protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        operationState: AssetOperationState
    ) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
