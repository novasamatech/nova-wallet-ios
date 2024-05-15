import UIKit
import SoraUI

final class BackupAttentionViewLayout: UIView {
    var checkBoxScrollableView = CheckBoxIconDetailsScrollableView()

    var agreeButton: UIControl?

    var blurredBottomView: OverlayBlurBackgroundView = .create { view in
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlockBackground()!
        view.overlayView.strokeColor = R.color.colorContainerBorder()!
        view.overlayView.strokeWidth = 1.5

        view.sideLength = 16
        view.cornerCut = [.topLeft, .topRight]
    }

    private var viewModel: Model?
    private var appearanceAnimator: ViewAnimatorProtocol?
    private var disappearanceAnimator: ViewAnimatorProtocol?

    convenience init(
        appearanceAnimator: ViewAnimatorProtocol?,
        disappearanceAnimator: ViewAnimatorProtocol?
    ) {
        self.init(frame: .zero)

        self.appearanceAnimator = appearanceAnimator
        self.disappearanceAnimator = disappearanceAnimator
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        setupLayout()
    }

    func bind(viewModel: Model) {
        if viewModel.button != self.viewModel?.button {
            let agreeButton = makeAgreeButton(for: viewModel.button)
            setupAgreeButton(with: agreeButton)
        }

        self.viewModel = viewModel
        checkBoxScrollableView.bind(viewModel: viewModel.rows)
    }
}

// MARK: Model

extension BackupAttentionViewLayout {
    struct Model {
        let rows: CheckBoxIconDetailsScrollableView.Model
        let button: ButtonModel
    }

    enum ButtonModel: Equatable {
        case active(title: String)
        case inactive(title: String)

        static func == (lhs: ButtonModel, rhs: ButtonModel) -> Bool {
            switch (lhs, rhs) {
            case (.active, .active):
                return true
            case (.inactive, .inactive):
                return true
            default:
                return false
            }
        }
    }
}

// MARK: Private

private extension BackupAttentionViewLayout {
    func setupLayout() {
        addSubview(checkBoxScrollableView)
        checkBoxScrollableView.containerView.scrollContentBottomOffset = UIConstants.scrollBottomOffset(for: self)
        checkBoxScrollableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(blurredBottomView)
        blurredBottomView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.bottomBlurViewHeight(for: self))

            // hiding the border at the edges of the screen
            make.leading.equalToSuperview().offset(-0.5)
            make.trailing.bottom.equalToSuperview().offset(0.5)
        }
    }

    func makeAgreeButton(for viewModel: ButtonModel) -> UIControl {
        switch viewModel {
        case let .active(title):
            let button = TriangularedButton()
            button.imageWithTitleView?.title = title
            button.applyEnabledStyle()

            return button
        case let .inactive(title):
            let button = TriangularedBlurButton()
            button.imageWithTitleView?.title = title
            button.applyDisabledStyle()

            return button
        }
    }

    func setupAgreeButton(with button: UIControl) {
        guard let agreeButton else {
            showButtonWithAnimation(button)
            return
        }

        changeButtonWithAnimation(button)
    }

    func changeButtonWithAnimation(_ button: UIControl) {
        guard let agreeButton else { return }

        disappearanceAnimator?.animate(view: agreeButton) { [weak self] _ in
            guard let self else { return }
            agreeButton.removeFromSuperview()

            showButtonWithAnimation(button)
        }
    }

    func showButtonWithAnimation(_ button: UIControl) {
        button.alpha = 0
        agreeButton = button

        blurredBottomView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        appearanceAnimator?.animate(view: button, completionBlock: nil)
    }
}

private extension UIConstants {
    static func bottomBlurViewHeight(for view: UIView) -> CGFloat {
        view.safeAreaInsets.bottom + 84
    }

    static func scrollBottomOffset(for view: UIView) -> CGFloat {
        view.safeAreaInsets.bottom + bottomBlurViewHeight(for: view) + 16
    }
}
