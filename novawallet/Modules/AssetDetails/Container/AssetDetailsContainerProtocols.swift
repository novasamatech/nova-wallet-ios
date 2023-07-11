protocol AssetDetailsContainerViewFactoryProtocol {
    static func createView(chain: ChainModel, asset: AssetModel) -> AssetDetailsContainerViewProtocol?
}

protocol AssetDetailsContainerViewProtocol: ControllerBackedProtocol {}
