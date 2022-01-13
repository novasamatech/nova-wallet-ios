import UIKit
import SoraUI

final class DAppSearchViewLayout: UIView {
    let searchBar = DAppSearchBar()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
