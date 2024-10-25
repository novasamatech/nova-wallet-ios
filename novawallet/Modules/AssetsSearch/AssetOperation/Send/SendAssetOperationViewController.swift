final class SendAssetOperationViewController: AssetOperationViewController {
    var sendPresenter: SendAssetOperationPresenterProtocol? {
        presenter as? SendAssetOperationPresenterProtocol
    }

    override func setupCollectionManager() {
        collectionViewManager = SendAssetOperationCollectionManager(
            view: rootView,
            groupsViewModel: groupsViewModel,
            delegate: self,
            actionDelegate: self,
            selectedLocale: selectedLocale
        )
    }
}

extension SendAssetOperationViewController: SendAssetOperationCollectionManagerActionDelegate {
    func actionBuy() {
        sendPresenter?.buy()
    }
}
