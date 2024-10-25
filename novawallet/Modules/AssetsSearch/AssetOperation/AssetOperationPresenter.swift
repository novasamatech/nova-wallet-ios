import Foundation

protocol AssetOperationPresenterProtocol {
    func selectGroup(with symbol: AssetModel.Symbol)
}

class AssetOperationPresenter: AssetsSearchPresenter, AssetOperationPresenterProtocol {
    func selectGroup(with _: AssetModel.Symbol) {
        fatalError("Must be overriden by subsclass")
    }
}
