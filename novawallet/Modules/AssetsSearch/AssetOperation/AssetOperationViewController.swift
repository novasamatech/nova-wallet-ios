class AssetOperationViewController: AssetsSearchViewController {
    override func setupCollectionManager() {
        collectionViewManager = AssetOperationCollectionManager(
            view: rootView,
            groupsViewModel: groupsViewModel,
            delegate: self,
            selectedLocale: selectedLocale
        )
    }
}
