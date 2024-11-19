import UIKit

final class SwapAssetsOperationViewLayout: BaseAssetsSearchViewLayout {
    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.tintColor = R.color.colorIconPrimary()
        view.hidesWhenStopped = true
    }

    override func createSearchView() -> SearchViewProtocol {
        let view = TopCustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        return view
    }

    override func setup() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
        super.setup()

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
