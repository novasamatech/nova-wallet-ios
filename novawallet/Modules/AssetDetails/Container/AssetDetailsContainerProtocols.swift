protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        operationState: AssetOperationState,
        ahmInfoSnapshot: AHMInfoService.Snapshot
    ) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
