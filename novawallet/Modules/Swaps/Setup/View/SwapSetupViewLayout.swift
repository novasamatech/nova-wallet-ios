import UIKit
import UIKit_iOS

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

    let loadableActionView = LoadableActionView()

    var actionButton: TriangularedButton {
        loadableActionView.actionButton
    }

    let switchButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconActionSwap()
    }

    let detailsView: SwapDetailsView = .create {
        $0.contentInsets = .zero
        $0.setExpanded(false, animated: false)
    }

    var rateCell: SwapInfoViewCell {
        detailsView.rateCell
    }

    var routeCell: SwapRouteViewCell {
        detailsView.routeCell
    }

    var execTimeCell: SwapInfoViewCell {
        detailsView.execTimeCell
    }

    var networkFeeCell: SwapNetworkFeeViewCell {
        detailsView.networkFeeCell
    }

    var payIssueLabel: UILabel?

    var receiveIssueLabel: UILabel?

    private func setupPayIssueLabel() -> UILabel {
        if let payIssueLabel = payIssueLabel {
            return payIssueLabel
        }

        let label = UILabel(style: .caption1Negative)
        label.numberOfLines = 0

        insertArrangedSubview(label, after: payAmountInputView, spacingAfter: 8)
        stackView.setCustomSpacing(8, after: payAmountInputView)

        payIssueLabel = label

        return label
    }

    private func setupReceiveIssueLabel() -> UILabel {
        if let receiveIssueLabel = receiveIssueLabel {
            return receiveIssueLabel
        }

        let label = UILabel(style: .caption1Negative)
        label.numberOfLines = 0

        insertArrangedSubview(label, after: receiveAmountInputView, spacingAfter: 8)
        stackView.setCustomSpacing(8, after: receiveAmountInputView)

        receiveIssueLabel = label

        return label
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)

        addSubview(loadableActionView)
        loadableActionView.snp.makeConstraints { make in
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
        detailsView.titleControl.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDetailsTitle()

        rateCell.titleButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.swapsSetupDetailsRate()

        routeCell.titleButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsRoute()

        execTimeCell.titleButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsExecTime()

        networkFeeCell.titleButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsTotalFee()

        rateCell.titleButton.invalidateLayout()
        routeCell.titleButton.invalidateLayout()
        execTimeCell.titleButton.invalidateLayout()
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

    func hideIssues() {
        hidePayIssue()
        hideReceiveIssue()
    }

    func displayPayIssue(with text: String) {
        let payIssueLabel = setupPayIssueLabel()
        payIssueLabel.text = text

        payAmountInputView.applyInput(style: .error)
    }

    func hidePayIssue() {
        payIssueLabel?.removeFromSuperview()
        payIssueLabel = nil

        stackView.setCustomSpacing(12, after: payAmountInputView)

        payAmountInputView.applyInput(style: .normal)
    }

    func displayReceiveIssue(with text: String) {
        let receiveIssueLabel = setupReceiveIssueLabel()
        receiveIssueLabel.text = text

        receiveAmountInputView.applyInput(style: .error)
    }

    func hideReceiveIssue() {
        receiveIssueLabel?.removeFromSuperview()
        receiveIssueLabel = nil

        stackView.setCustomSpacing(16, after: receiveAmountInputView)

        receiveAmountInputView.applyInput(style: .normal)
    }
}
