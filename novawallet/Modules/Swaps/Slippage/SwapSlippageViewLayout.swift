import UIKit
import UIKit_iOS

final class SwapSlippageViewLayout: ScrollableContainerLayoutView {
    let slippageButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconInfoFilled()
        $0.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        $0.imageWithTitleView?.titleFont = .semiBoldBody
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        $0.imageWithTitleView?.layoutType = .horizontalLabelFirst
        $0.contentInsets = .init(top: 0, left: 0, bottom: 12, right: 0)
    }

    let amountInput = PercentInputView()

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let errorLabel = UILabel(style: .caption1Negative, textAlignment: .left, numberOfLines: 0)
    private var warningView: InlineAlertView?

    override func setupLayout() {
        super.setupLayout()
        let title = UIView.hStack([
            slippageButton,
            FlexibleSpaceView()
        ])
        addArrangedSubview(title)
        slippageButton.setContentHuggingPriority(.low, for: .horizontal)
        addArrangedSubview(amountInput, spacingAfter: 8)

        amountInput.snp.makeConstraints {
            $0.height.equalTo(48)
        }

        errorLabel.isHidden = true
        addArrangedSubview(errorLabel, spacingAfter: 8)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func set(error: String?) {
        errorLabel.text = error
        errorLabel.isHidden = error.isNilOrEmpty
        amountInput.apply(style: error.isNilOrEmpty ? .normal : .error)
    }

    func set(warning: String?) {
        applyWarning(
            on: &warningView,
            after: errorLabel,
            text: warning,
            spacing: 16
        )
    }
}
