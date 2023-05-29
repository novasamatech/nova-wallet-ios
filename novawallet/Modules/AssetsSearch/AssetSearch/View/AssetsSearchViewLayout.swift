import UIKit
import SoraUI

final class AssetsSearchViewLayout: BaseAssetsSearchViewLayout {
    let backgroundView = MultigradientView.background

    override func createSearchView() -> SearchViewProtocol {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        view.optionalCancelButton?.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 16)
        return view
    }

    override func setup() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        super.setup()
    }
}
