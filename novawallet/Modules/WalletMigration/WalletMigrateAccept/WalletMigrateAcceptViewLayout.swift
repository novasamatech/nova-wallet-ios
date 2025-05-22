import UIKit

final class WalletMigrateAcceptViewLayout: SCLoadableActionLayoutView {
    let titleView: MultiValueView = .create { view in
        view.valueTop.apply(style: .title3Primary)
        view.valueTop.textAlignment = .left
        view.valueTop.numberOfLines = 0
        view.valueBottom.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.textAlignment = .left
        view.valueBottom.numberOfLines = 0
        view.spacing = 8
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 24)
    }
}
