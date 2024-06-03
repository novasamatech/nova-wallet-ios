import Foundation
import UIKit
import SoraUI
import SnapKit

final class AccountCreateViewLayout: ScrollableContainerLayoutView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let mnemonicCardView: HiddenMnemonicCardView = .create { view in
        view.alpha = 0
    }

    var checkBoxViews: [CheckBoxIconDetailsView] = [
        .init(frame: .zero),
        .init(frame: .zero),
        .init(frame: .zero)
    ]

    let footer: BlurBackgroundView = .create { view in
        view.sideLength = Constants.footerCornerRadius
        view.cornerCut = [.topLeft, .topRight]
    }

    let agreeButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    private let appearanceAnimator: ViewAnimatorProtocol

    var footerHeightConstraint: Constraint?

    private var checkboxListViewModel: BackupAttentionViewLayout.Model?

    init(appearanceAnimator: ViewAnimatorProtocol) {
        self.appearanceAnimator = appearanceAnimator

        super.init(frame: .zero)

        setupHandlers()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        updateFooterHeight()
        updateStackButtonOffset()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleLabel, spacingAfter: 24)

        addArrangedSubview(mnemonicCardView, spacingAfter: 24)

        checkBoxViews.forEach { addArrangedSubview($0, spacingAfter: 8) }

        addSubview(footer)
        footer.snp.makeConstraints { make in
            footerHeightConstraint = make.height.equalTo(Constants.bottomBlurViewHeight(for: self)).constraint

            // hiding the border at the edges of the screen
            make.leading.equalToSuperview().offset(-0.5)
            make.trailing.bottom.equalToSuperview().offset(0.5)
        }

        footer.addSubview(agreeButton)
        agreeButton.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }
    }

    override func setupStyle() {
        super.setupStyle()

        containerView.scrollView.showsVerticalScrollIndicator = false
    }

    func bind(_ checkboxListViewModel: BackupAttentionViewLayout.Model) {
        self.checkboxListViewModel = checkboxListViewModel

        switch checkboxListViewModel.button {
        case let .active(title, _):
            agreeButton.imageWithTitleView?.title = title
            agreeButton.applyEnabledStyle()
            agreeButton.isEnabled = true
        case let .inactive(title):
            agreeButton.imageWithTitleView?.title = title
            agreeButton.applyDisabledStyle()
            agreeButton.isEnabled = false
        }

        checkBoxViews
            .enumerated()
            .forEach { $0.element.bind(viewModel: checkboxListViewModel.rows[$0.offset]) }

        setNeedsLayout()
    }

    func displayMnemonicCard() {
        appearanceAnimator.animate(
            view: mnemonicCardView,
            completionBlock: nil
        )
    }

    func hideMnemonicCard() {
        mnemonicCardView.alpha = 0
    }
}

// MARK: Private

private extension AccountCreateViewLayout {
    func setupHandlers() {
        agreeButton.addTarget(
            self,
            action: #selector(continueAction),
            for: .touchUpInside
        )
    }

    func updateFooterHeight() {
        footerHeightConstraint?.layoutConstraints.first?.constant = Constants.bottomBlurViewHeight(for: self)
    }

    func updateStackButtonOffset() {
        stackView.layoutMargins.bottom = Constants.scrollBottomOffset(for: self)
    }

    @objc func continueAction() {
        guard case let .active(_, action) = checkboxListViewModel?.button else { return }

        action()
    }
}

private extension AccountCreateViewLayout {
    enum Constants {
        static let footerCornerRadius: CGFloat = 16
        static let footerBorderWidth: CGFloat = 16
        static func bottomBlurViewHeight(for view: UIView) -> CGFloat {
            view.safeAreaInsets.bottom + 84
        }

        static func scrollBottomOffset(for view: UIView) -> CGFloat {
            view.safeAreaInsets.bottom + bottomBlurViewHeight(for: view) + 16
        }
    }
}
