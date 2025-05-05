import UIKit
import UIKit_iOS
import SnapKit

final class BackupAttentionViewLayout: ScrollableContainerLayoutView {
    var titleView = BackupAttentionTableTitleView()

    var checkBoxViews: [CheckBoxIconDetailsView] = [
        .init(frame: .zero),
        .init(frame: .zero),
        .init(frame: .zero)
    ]

    let footer: BlurBackgroundView = .create {
        $0.sideLength = UIConstants.footerCornerRadius
        $0.cornerCut = [.topLeft, .topRight]
    }

    let agreeButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
        $0.addTarget(self, action: #selector(continueAction), for: .touchUpInside)
    }

    var footerHeightConstraint: Constraint?

    private var viewModel: Model?

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        updateFooterHeight()
        updateStackButtonOffset()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 16)

        checkBoxViews.forEach { addArrangedSubview($0, spacingAfter: 12) }

        addSubview(footer)
        footer.snp.makeConstraints { make in
            footerHeightConstraint = make.height.equalTo(UIConstants.bottomBlurViewHeight(for: self)).constraint

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

    func bind(viewModel: Model) {
        self.viewModel = viewModel

        switch viewModel.button {
        case let .active(title, action):
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
            .forEach { $0.element.bind(viewModel: viewModel.rows[$0.offset]) }

        setNeedsLayout()
    }
}

// MARK: Model

extension BackupAttentionViewLayout {
    struct Model {
        let rows: [CheckBoxIconDetailsView.Model]
        let button: ButtonModel
    }

    enum ButtonModel {
        case active(title: String, action: () -> Void)
        case inactive(title: String)
    }
}

// MARK: Private

private extension BackupAttentionViewLayout {
    func updateFooterHeight() {
        footerHeightConstraint?.layoutConstraints.first?.constant = UIConstants.bottomBlurViewHeight(for: self)
    }

    func updateStackButtonOffset() {
        stackView.layoutMargins.bottom = UIConstants.scrollBottomOffset(for: self)
    }

    @objc func continueAction() {
        guard case let .active(_, action) = viewModel?.button else { return }

        action()
    }
}

// MARK: UIConstants

private extension UIConstants {
    static let footerCornerRadius: CGFloat = 16
    static let footerBorderWidth: CGFloat = 16
    static func bottomBlurViewHeight(for view: UIView) -> CGFloat {
        view.safeAreaInsets.bottom + 84
    }

    static func scrollBottomOffset(for view: UIView) -> CGFloat {
        view.safeAreaInsets.bottom + bottomBlurViewHeight(for: view) + 16
    }
}
