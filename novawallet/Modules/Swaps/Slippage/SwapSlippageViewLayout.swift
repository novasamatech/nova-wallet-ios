import UIKit
import SoraUI

final class SwapSlippageViewLayout: ScrollableContainerLayoutView {
    let slippageButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconInfoFilled()?.tinted(
            with: R.color.colorIconSecondary()!
        )
        $0.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        $0.imageWithTitleView?.titleFont = .regularFootnote
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        $0.imageWithTitleView?.layoutType = .horizontalLabelFirst
    }

    let amountInput = SwapSlippageInputView()

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()
        let title = UIView.hStack([
            slippageButton,
            FlexibleSpaceView()
        ])
        addArrangedSubview(title, spacingAfter: 12)
        slippageButton.setContentHuggingPriority(.low, for: .horizontal)
        addArrangedSubview(amountInput)

        amountInput.snp.makeConstraints {
            $0.height.equalTo(48)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
