import UIKit
import SoraUI

final class AssetsSearchViewLayout: BaseAssetsSearchViewLayout {
    let backgroundView = MultigradientView.background

    override func createSearchView() -> SearchViewProtocol {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
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
