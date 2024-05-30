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

    let continueButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        containerView.scrollView.showsVerticalScrollIndicator = false
    }

    func setButtonDisabled(with title: String) {
        continueButton.applyDisabledStyle()
        continueButton.imageWithTitleView?.title = title
        continueButton.isUserInteractionEnabled = false
    }

    func setButtonEnabled(with title: String) {
        continueButton.applyDefaultStyle()
        continueButton.imageWithTitleView?.title = title
        continueButton.isUserInteractionEnabled = true
    }
}

// MARK: Private

private extension AccountConfirmViewLayout {
    func setupHandlers() {
        continueButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    @objc func actionContinue() {
        delegate?.didTapContinue()
    }
}

private extension AccountConfirmViewLayout {
    enum Constants {
        static let stackVerticalSpacing: CGFloat = 24
    }
}
