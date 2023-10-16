import UIKit
import SoraUI

final class SwapSetupViewLayout: ScrollableContainerLayoutView {
    let payAmountView: TitleHorizontalMultiValueView = .create {
        $0.titleView.apply(style: .footnoteSecondary)
        $0.detailsTitleLabel.apply(style: .footnoteAccentText)
        $0.detailsValueLabel.apply(style: .footnotePrimary)
    }

    let payAmountInputView = SwapAmountInputView()

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
    }

    var rateCell: SwapRateView {
        detailsView.rateCell
    }

    var networkFeeCell: SwapNetworkFeeView {
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
        addArrangedSubview(payAmountInputView, spacingAfter: 24)
        payAmountInputView.snp.makeConstraints {
            $0.height.equalTo(64)
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
            $0.top.equalTo(payAmountInputView.snp.bottom).offset(9)
            $0.bottom.equalTo(receiveAmountInputView.snp.top).offset(-9)
            $0.centerX.equalTo(payAmountInputView.snp.centerX)
        }
    }

    func setup(locale: Locale) {
        detailsView.titleControl.titleLabel.text = R.string.localizable.swapsSetupDetailsTitle(
            preferredLanguages: locale.rLanguages
        )
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()
    }
}
