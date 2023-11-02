import UIKit
import SoraUI

final class SwapSetupViewLayout: ScrollableContainerLayoutView {
    let payAmountView = SwapSetupTitleView(frame: .zero)

    let payAmountInputView = SwapAmountInputView()

    let depositTokenButton: TriangularedButton = .create {
        $0.applySecondaryDefaultStyle()
        $0.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
    }

    let receiveAmountView: TitleHorizontalMultiValueView = .create {
        $0.titleView.apply(style: .footnoteSecondary)
        $0.detailsTitleLabel.apply(style: .footnoteSecondary)
        $0.detailsValueLabel.apply(style: .footnotePrimary)
    }

    let receiveAmountInputView = SwapAmountInputView()

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let switchButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconActionSwap()
    }

    let detailsView: SwapDetailsView = .create {
        $0.setExpanded(false, animated: false)
        $0.contentInsets = .zero
    }

    var rateCell: SwapInfoViewCell {
        detailsView.rateCell
    }

    var networkFeeCell: SwapNetworkFeeViewCell {
        detailsView.networkFeeCell
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addArrangedSubview(payAmountView, spacingAfter: 8)
        payAmountView.snp.makeConstraints {
            $0.height.equalTo(18)
        }
        addArrangedSubview(payAmountInputView, spacingAfter: 12)
        payAmountInputView.snp.makeConstraints {
            $0.height.equalTo(64)
        }
        addArrangedSubview(depositTokenButton, spacingAfter: 24)
        depositTokenButton.snp.makeConstraints {
            $0.height.equalTo(44)
        }
        addArrangedSubview(receiveAmountView, spacingAfter: 8)
        receiveAmountView.snp.makeConstraints {
            $0.height.equalTo(18)
        }
        addArrangedSubview(receiveAmountInputView, spacingAfter: 16)
        receiveAmountInputView.snp.makeConstraints {
            $0.height.equalTo(64)
        }

        addArrangedSubview(detailsView, spacingAfter: 8)

        addSubview(switchButton)
        switchButton.snp.makeConstraints {
            $0.height.equalTo(switchButton.snp.width)
            $0.bottom.equalTo(receiveAmountInputView.snp.top).offset(-4)
            $0.centerX.equalTo(payAmountInputView.snp.centerX)
        }
    }

    func setup(locale: Locale) {
        detailsView.titleControl.titleLabel.text = R.string.localizable.swapsSetupDetailsTitle(
            preferredLanguages: locale.rLanguages
        )
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(
            preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetwork(
            preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()
    }

    func changeDepositTokenButtonVisibility(hidden: Bool) {
        if hidden {
            stackView.setCustomSpacing(24, after: payAmountInputView)
        } else {
            stackView.setCustomSpacing(12, after: payAmountInputView)
        }
        depositTokenButton.isHidden = hidden
        setNeedsLayout()
    }
}
