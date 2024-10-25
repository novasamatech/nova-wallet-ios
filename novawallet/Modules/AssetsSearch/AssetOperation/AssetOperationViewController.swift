class AssetOperationViewController: AssetsSearchViewController {
    var assetOperationPresenter: AssetOperationPresenterProtocol? {
        presenter as? AssetOperationPresenterProtocol
    }

    override func setupCollectionManager() {
        collectionViewManager = AssetOperationCollectionManager(
            view: rootView,
            groupsViewModel: groupsViewModel,
            delegate: self,
            selectedLocale: selectedLocale
        )
    }
}

extension AssetOperationViewController: AssetOperationCollectionManagerDelegate {
    func selectGroup(with symbol: AssetModel.Symbol) {
        assetOperationPresenter?.selectGroup(with: symbol)
    }
}

protocol AssetOperationCollectionManagerDelegate: AnyObject {
    func selectGroup(with symbol: AssetModel.Symbol)
}
