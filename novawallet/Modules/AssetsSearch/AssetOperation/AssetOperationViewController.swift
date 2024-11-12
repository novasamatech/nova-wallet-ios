class AssetOperationViewController: AssetsSearchViewController {
    override func setupCollectionManager() {
        collectionViewManager = AssetOperationCollectionManager(
            view: rootView,
            groupsViewModel: groupsViewModel,
            delegate: self,
            selectedLocale: selectedLocale
        )
    }

    override func setupLocalization() {
        super.setupLocalization()

        let languages = selectedLocale.rLanguages

        rootView.searchBar.textField.placeholder = if assetGroupsLayoutStyle == .networks {
            R.string.localizable.assetsSearchPlaceholder(
                preferredLanguages: languages
            )
        } else {
            R.string.localizable.assetsSearchTokenHint(
                preferredLanguages: languages
            )
        }
    }
}
