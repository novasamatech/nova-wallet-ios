import Foundation
import UIKit
import UIKit_iOS

protocol AccountConfirmViewLayoutDelegate: AnyObject {
    func didTapContinue()
    func didTapSkip()
}

class AccountConfirmViewLayout: ScrollableContainerLayoutView {
    weak var delegate: AccountConfirmViewLayoutDelegate?

    private var showsSkipButton: Bool = false

    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let mnemonicCardView = MnemonicCardView()
    let mnemonicGridView = MnemonicGridView()

    let skipButton: TriangularedButton = .create { button in
        button.applyDisabledStyle()
    }

    let continueButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    init(showsSkipButton: Bool) {
        self.showsSkipButton = showsSkipButton
        super.init(frame: .zero)

        setupHandlers()
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

        if showsSkipButton {
            addSubview(skipButton)

            skipButton.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
                make.bottom.equalTo(self.continueButton.snp.top).offset(-12)
                make.height.equalTo(UIConstants.actionHeight)
            }
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

        skipButton.addTarget(
            self,
            action: #selector(actionSkip),
            for: .touchUpInside
        )
    }

    @objc func actionContinue() {
        delegate?.didTapContinue()
    }

    @objc func actionSkip() {
        delegate?.didTapSkip()
    }
}

private extension AccountConfirmViewLayout {
    enum Constants {
        static let stackVerticalSpacing: CGFloat = 24
    }
}
