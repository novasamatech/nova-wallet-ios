import Foundation

final class AssetOperationNetworkListWireframe: AssetOperationNetworkListWireframeProtocol {
    func showOperation(for chainAsset: ChainAsset) {
        print(chainAsset)
    }
}
