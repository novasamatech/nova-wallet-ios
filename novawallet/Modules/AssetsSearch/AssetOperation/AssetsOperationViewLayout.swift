final class AssetsOperationViewLayout: BaseAssetsSearchViewLayout {
    override func setup() {
        super.setup()

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func createSearchView() -> SearchViewProtocol {
        let view = TopCustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        return view
    }
}
