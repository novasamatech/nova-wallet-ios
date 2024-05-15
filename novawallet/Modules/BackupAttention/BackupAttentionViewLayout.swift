import UIKit
import SoraUI

final class BackupAttentionViewLayout: UIView {
    var checkBoxScrollableView = CheckBoxIconDetailsScrollableView()

    var agreeButton: UIControl?

    var blurredBottomView: BlockBackgroundView = .create { view in
        view.layer.borderWidth = 1
        view.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        view.layer.cornerRadius = 16
        view.sideLength = 16
        view.cornerCut = [.topLeft, .topRight]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: Model) {
        let agreeButton = makeAgreeButton(for: viewModel.button)
        setupAgreeButton(with: agreeButton)
        checkBoxScrollableView.bind(viewModel: viewModel.rows)
    }
}

// MARK: Model

extension BackupAttentionViewLayout {
    struct Model {
        let rows: CheckBoxIconDetailsScrollableView.Model
        let button: ButtonModel
    }

    enum ButtonModel {
        case active(title: String)
        case inactive(title: String)
    }
}

// MARK: Private

private extension BackupAttentionViewLayout {
    func setupLayout() {
        addSubview(checkBoxScrollableView)
        checkBoxScrollableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(blurredBottomView)
        blurredBottomView.snp.makeConstraints { make in
            // hiding the border on edges of screen
            make.leading.equalToSuperview().offset(-1)
            make.trailing.bottom.equalToSuperview().offset(1)

            make.height.equalTo(UIConstants.bottomBlurViewHeight)
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

    func setupAgreeButton(with control: UIControl) {
        agreeButton?.removeFromSuperview()
        agreeButton = control

        blurredBottomView.addSubview(control)
        control.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }
    }
}

private extension UIConstants {
    static let bottomBlurViewHeight: CGFloat = 118
}
