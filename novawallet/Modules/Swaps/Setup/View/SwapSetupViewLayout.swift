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

    let detailsHeaderCell: CollapsableView = .create {
        $0.actionControl.addTarget(self, action: #selector(detailsControlAction), for: .valueChanged)
        $0.actionControl.imageView.isUserInteractionEnabled = false
    }

    let detailsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        $0.isHidden = true
    }

    let rateCell: StackTitleMultiValueCell = .create {
        $0.titleLabel.apply(style: .footnoteSecondary)
        $0.rowContentView.titleView.iconWidth = 16
        $0.rowContentView.titleView.imageView.image = R.image.iconInfoFilledAccent()
    }

    let networkFeeCell = StackTitleMultiValueEditCell()

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

        addArrangedSubview(detailsHeaderCell, spacingAfter: 8)
        addArrangedSubview(detailsTableView)
        detailsTableView.addArrangedSubview(rateCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        addSubview(switchButton)
        switchButton.snp.makeConstraints {
            $0.height.equalTo(switchButton.snp.width)
            $0.top.equalTo(payAmountInputView.snp.bottom).offset(9)
            $0.bottom.equalTo(receiveAmountInputView.snp.top).offset(-9)
            $0.centerX.equalTo(payAmountInputView.snp.centerX)
        }
    }

    func setup(locale: Locale) {
        detailsHeaderCell.titleLabel.text = R.string.localizable.swapsSetupDetailsTitle(
            preferredLanguages: locale.rLanguages
        )
        rateCell.titleLabel.text = R.string.localizable.swapsSetupDetailsRate(preferredLanguages: locale.rLanguages)
        networkFeeCell.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
    }

    @objc
    private func detailsControlAction() {
        detailsTableView.isHidden = !detailsHeaderCell.actionControl.isActivated

        detailsHeaderCell.actionControl.invalidateLayout()
        detailsHeaderCell.setNeedsLayout()
    }
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
        addArrangedSubview(receiveAmountInputView)
        receiveAmountInputView.snp.makeConstraints {
            $0.height.equalTo(64)
        }

        addSubview(switchButton)
        switchButton.snp.makeConstraints {
            $0.height.equalTo(switchButton.snp.width)
            $0.top.equalTo(payAmountInputView.snp.bottom).offset(9)
            $0.bottom.equalTo(receiveAmountInputView.snp.top).offset(-9)
            $0.centerX.equalTo(payAmountInputView.snp.centerX)
        }
    }
}
