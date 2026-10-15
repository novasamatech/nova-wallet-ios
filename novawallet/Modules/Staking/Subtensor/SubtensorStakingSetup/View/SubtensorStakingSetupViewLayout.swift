import UIKit

final class SubtensorStakingSetupViewLayout: SubtensorAmountSetupLayout {
    let getTaoCardView: SubtensorGetTaoCardView = .create { view in
        view.isHidden = true
    }

    let reserveAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let selectionAlert: InlineAlertView = .create { $0.isHidden = true }
    let browseButton = UIButton(type: .system)

    let detailsTableView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = 12
    }

    let validatorCardView: SubtensorValidatorCardView = .create { $0.applyEmbeddedStyle() }
    let rootPickCardView: SubtensorRootPickCardView = .create { $0.isHidden = true }

    let sectionLabel: UILabel = .create { label in
        label.apply(style: .semiboldCaps2Secondary)
        label.isHidden = true
    }

    let pickCardView: SubtensorPickCardView = .create { view in
        view.isHidden = true
    }

    let avgBuyPriceTableView: StackTableView = .create { view in
        view.isHidden = true
    }

    let avgBuyPriceCell = StackTitleMultiValueCell()

    func placeCaption(afterAction: Bool) {
        bottomStack.removeArrangedSubview(captionLabel)
        bottomStack.insertArrangedSubview(captionLabel, at: afterAction ? 1 : 0)
    }

    override func setupLayout() {
        super.setupLayout()

        setupAmountLayout()
        setupDetailsLayout()
    }

    func setAvgBuyPriceVisible(_ isVisible: Bool) {
        avgBuyPriceTableView.isHidden = !isVisible

        containerView.stackView.setCustomSpacing(
            isVisible ? Constants.avgBuyPriceSpacing : Constants.detailsSpacing,
            after: pickCardView
        )
    }
}

private extension SubtensorStakingSetupViewLayout {
    enum Constants {
        static let avgBuyPriceSpacing: CGFloat = 8
        static let detailsSpacing: CGFloat = 16
        static let afterAvgBuyPriceSpacing: CGFloat = 12
    }

    func setupAmountLayout() {
        containerView.stackView.addArrangedSubview(getTaoCardView)

        containerView.stackView.setCustomSpacing(12.0, after: amountInputView)
        containerView.stackView.setCustomSpacing(16.0, after: getTaoCardView)

        containerView.stackView.addArrangedSubview(reserveAlertView)
        containerView.stackView.setCustomSpacing(16.0, after: reserveAlertView)
    }

    func setupDetailsLayout() {
        containerView.stackView.addArrangedSubview(sectionLabel)
        containerView.stackView.setCustomSpacing(8, after: sectionLabel)
        containerView.stackView.addArrangedSubview(selectionAlert)
        containerView.stackView.setCustomSpacing(16, after: selectionAlert)
        containerView.stackView.addArrangedSubview(detailsTableView)

        let detailsStack = UIView.vStack(spacing: 0, [validatorCardView, networkFeeCell])
        detailsTableView.addSubview(detailsStack)
        detailsStack.snp.makeConstraints { $0.edges.equalToSuperview() }
        networkFeeCell.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        SubtensorDividerStyle.apply(to: networkFeeCell, hasPrevious: true)
        containerView.stackView.addArrangedSubview(rootPickCardView)

        containerView.stackView.addArrangedSubview(pickCardView)
        containerView.stackView.setCustomSpacing(Constants.detailsSpacing, after: pickCardView)
        containerView.stackView.addArrangedSubview(browseButton)
        browseButton.contentHorizontalAlignment = .right
        browseButton.titleLabel?.font = .semiBoldFootnote
        browseButton.snp.makeConstraints { $0.height.equalTo(44) }
        containerView.stackView.addArrangedSubview(avgBuyPriceTableView)
        containerView.stackView.setCustomSpacing(Constants.afterAvgBuyPriceSpacing, after: avgBuyPriceTableView)

        avgBuyPriceTableView.addArrangedSubview(avgBuyPriceCell)
    }
}
