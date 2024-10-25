import Foundation

protocol AssetOperationPresenterProtocol {
    func selectGroup(with symbol: AssetModel.Symbol)
}

class AssetOperationPresenter: AssetsSearchPresenter, AssetOperationPresenterProtocol {
    func selectGroup(with _: AssetModel.Symbol) {
        fatalError("Must be overriden by subsclass")
    }

    func processWithCheck(
        _ symbol: String,
        onSingleInstance: (ChainAsset) -> Void,
        onMultipleInstances: (MultichainToken) -> Void
    ) {
        guard let multichainToken = result?.assetGroups.first(
            where: { $0.multichainToken.symbol == symbol }
        )?.multichainToken else {
            return
        }

        if multichainToken.instances.count > 1 {
            onMultipleInstances(multichainToken)
        } else if
            let chainAssetId = multichainToken.instances.first?.chainAssetId,
            let chainAsset = result?.state.chainAsset(for: chainAssetId) {
            onSingleInstance(chainAsset)
        }
    }
}
