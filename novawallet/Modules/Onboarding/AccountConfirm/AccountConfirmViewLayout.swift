import Foundation
import SoraUI

protocol AccountConfirmViewLayoutDelegate: AnyObject {
    func didTapContinue()
}

class AccountConfirmViewLayout: ScrollableContainerLayoutView {
    weak var delegate: AccountConfirmViewLayoutDelegate?

    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let mnemonicCardView = MnemonicCardView()
    let mnemonicGridView = MnemonicGridView()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(
            titleLabel,
            spacingAfter: Constants.stackVerticalSpacing
        )
        addArrangedSubview(
            mnemonicCardView,
            spacingAfter: Constants.stackVerticalSpacing
        )
        addArrangedSubview(mnemonicGridView)
    }

    override func setupStyle() {
        super.setupStyle()

        containerView.scrollView.showsVerticalScrollIndicator = false
    }
}

// MARK: Private

private extension AccountConfirmViewLayout {}

private extension AccountConfirmViewLayout {
    enum Constants {
        static let stackVerticalSpacing: CGFloat = 24
    }
}
