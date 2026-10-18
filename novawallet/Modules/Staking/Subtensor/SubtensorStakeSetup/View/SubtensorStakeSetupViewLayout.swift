import UIKit

final class SubtensorStakeSetupViewLayout: SubtensorAmountSetupLayout {
    let getTaoCardView: SubtensorGetTaoCardView = .create { view in
        view.isHidden = true
    }

    let reserveAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let selectionAlert: WarningView = .create { view in
        view.isHidden = true
        view.contentInsets.bottom = Constants.selectionAlertBottomInset
        view.contentView.sView.spacing = Constants.selectionAlertTitleSpacing
        view.contentView.sView.sView.spacing = 0
    }

    let pickSkeletonView = SubtensorPickCardSkeletonView()
    let browseView = SubtensorBrowseLinkView()

    let detailsTableView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = 12
    }

    let validatorCardView: SubtensorValidatorCardView = .create { $0.applyEmbeddedStyle() }

    let validatorCell: StackInfoTableCell = .create { cell in
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let apyCell: StackTableCell = .create { cell in
        cell.detailsLabel.textColor = R.color.colorTextPositive()
    }

    let sectionLabel: UILabel = .create { label in
        label.apply(style: .semiboldCaps1Secondary)
        label.isHidden = true
    }

    let pickCardView: SubtensorPickCardView = .create { view in
        view.isHidden = true
    }

    let avgBuyPriceTableView: StackTableView = .create { view in
        view.isHidden = true
    }

    let avgBuyPriceCell = StackTitleMultiValueCell()

    func setReserveWarning(_ warning: String?) {
        reserveAlertView.isHidden = warning == nil
        reserveAlertView.contentView.detailsLabel.text = warning
        containerView.stackView.setCustomSpacing(
            warning == nil ? Constants.amountSpacing : Constants.reserveWarningSpacing,
            after: amountInputView
        )
    }

    func setSelection(_ selection: SubtensorSetupSelectionViewModel?) {
        pickSkeletonView.setLoading(selection != nil)

        if let caption = selection?.caption {
            pickSkeletonView.bind(caption: caption)
        }
    }

    func setFailure(_ failure: WarningView.Model?) {
        selectionAlert.isHidden = failure == nil

        if let failure {
            selectionAlert.contentInsets.bottom = failure.learnMore != nil
                ? Constants.selectionAlertBottomInset
                : Constants.selectionAlertPlainBottomInset
            selectionAlert.bind(failure)
        }
    }

    func applyRootValidator(_ viewModel: SubtensorSetupRootValidatorViewModel) {
        switch viewModel {
        case let .card(card):
            validatorCardView.bind(viewModel: card)
            setValidatorRowsVisible(false)
        case let .rows(validator, apy):
            validatorCell.bind(viewModel: validator)
            apyCell.bind(details: apy)
            setValidatorRowsVisible(true)
        }
    }

    func setSection(_ title: String) {
        sectionLabel.applySubtensorCaps(title)
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

private extension SubtensorStakeSetupViewLayout {
    enum Constants {
        static let avgBuyPriceSpacing: CGFloat = 8
        static let detailsSpacing: CGFloat = 16
        static let afterAvgBuyPriceSpacing: CGFloat = 12
        static let amountSpacing: CGFloat = 24
        static let reserveWarningSpacing: CGFloat = 8
        static let selectionAlertBottomInset: CGFloat = 4
        static let selectionAlertPlainBottomInset: CGFloat = 10
        static let selectionAlertTitleSpacing: CGFloat = 8
        static let selectionAlertSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 11
        static let browseSpacing: CGFloat = 12
    }

    func setValidatorRowsVisible(_ isVisible: Bool) {
        validatorCardView.isHidden = isVisible
        validatorCell.isHidden = !isVisible
        apyCell.isHidden = !isVisible
    }

    func setupAmountLayout() {
        containerView.stackView.addArrangedSubview(getTaoCardView)

        containerView.stackView.setCustomSpacing(Constants.amountSpacing, after: amountInputView)
        containerView.stackView.setCustomSpacing(16.0, after: getTaoCardView)

        containerView.stackView.addArrangedSubview(reserveAlertView)
        containerView.stackView.setCustomSpacing(16.0, after: reserveAlertView)
    }

    func setupDetailsLayout() {
        containerView.stackView.addArrangedSubview(selectionAlert)
        containerView.stackView.setCustomSpacing(Constants.selectionAlertSpacing, after: selectionAlert)
        containerView.stackView.addArrangedSubview(sectionLabel)
        containerView.stackView.setCustomSpacing(Constants.sectionSpacing, after: sectionLabel)
        containerView.stackView.addArrangedSubview(detailsTableView)
        containerView.stackView.setCustomSpacing(Constants.browseSpacing, after: detailsTableView)

        let detailsStack = UIView.vStack(spacing: 0, [validatorCardView, validatorCell, apyCell, networkFeeCell])
        detailsTableView.addSubview(detailsStack)
        detailsStack.snp.makeConstraints { $0.edges.equalToSuperview() }
        apyCell.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        networkFeeCell.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        SubtensorDividerStyle.apply(to: apyCell, hasPrevious: true)
        SubtensorDividerStyle.apply(to: networkFeeCell, hasPrevious: true)
        containerView.stackView.addArrangedSubview(pickCardView)
        containerView.stackView.setCustomSpacing(Constants.detailsSpacing, after: pickCardView)
        containerView.stackView.addArrangedSubview(pickSkeletonView)
        containerView.stackView.setCustomSpacing(Constants.detailsSpacing, after: pickSkeletonView)
        containerView.stackView.addArrangedSubview(browseView)
        containerView.stackView.addArrangedSubview(avgBuyPriceTableView)
        containerView.stackView.setCustomSpacing(Constants.afterAvgBuyPriceSpacing, after: avgBuyPriceTableView)

        avgBuyPriceTableView.addArrangedSubview(avgBuyPriceCell)
    }
}
