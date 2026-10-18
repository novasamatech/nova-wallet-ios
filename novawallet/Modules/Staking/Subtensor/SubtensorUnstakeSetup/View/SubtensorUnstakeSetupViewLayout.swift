import UIKit

final class SubtensorUnstakeSetupViewLayout: SubtensorAmountSetupLayout {
    let detailsTableView = StackTableView()

    let receiveCell: StackTitleMultiValueCell = .create { cell in
        cell.canSelect = false
    }

    let swapRateCell = StackTitleMultiValueCell()

    let avgBuyPriceCell = StackTitleMultiValueCell()

    let earnedCell: StackTitleMultiValueCell = .create { cell in
        cell.canSelect = false
    }

    let validatorCell: StackInfoTableCell = .create { cell in
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        cell.accessoryImageView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!)
    }

    let validatorSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    let subnetValidatorCell: SubtensorValidatorDetailsCell = .create { cell in
        cell.rowContentView.bind(apy: nil)
    }

    let subnetValidatorSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    let noteLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    private(set) lazy var noteView: UIStackView = .create { view in
        view.addArrangedSubview(noteLabel)
        view.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.isLayoutMarginsRelativeArrangement = true
        view.isHidden = true
    }

    let feeAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let holdAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    override func setupLayout() {
        super.setupLayout()

        bottomStack.insertArrangedSubview(holdAlertView, at: 0)

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        amountInputView.iconRadius = Constants.inputIconRadius
        amountInputView.iconView.imageView.layer.cornerRadius = Constants.inputIconRadius
        amountInputView.iconView.imageView.clipsToBounds = true

        setupDetailsLayout()
    }

    func setupMode(isRoot: Bool) {
        validatorCell.isHidden = !isRoot
        subnetValidatorCell.isHidden = isRoot
        detailsTableView.updateLayout()
    }
}

private extension SubtensorUnstakeSetupViewLayout {
    func setupDetailsLayout() {
        containerView.stackView.addArrangedSubview(detailsTableView)

        detailsTableView.addArrangedSubview(receiveCell)
        detailsTableView.addArrangedSubview(swapRateCell)
        detailsTableView.addArrangedSubview(avgBuyPriceCell)
        detailsTableView.addArrangedSubview(earnedCell)
        detailsTableView.addArrangedSubview(subnetValidatorCell)
        detailsTableView.addArrangedSubview(validatorCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        containerView.stackView.setCustomSpacing(16.0, after: detailsTableView)

        containerView.stackView.addArrangedSubview(noteView)
        containerView.stackView.addArrangedSubview(feeAlertView)
        containerView.stackView.setCustomSpacing(16.0, after: feeAlertView)

        addSkeleton(validatorSkeletonView, to: validatorCell, width: 100)
        addSkeleton(subnetValidatorSkeletonView, to: subnetValidatorCell, width: 100)
    }
}

private extension SubtensorUnstakeSetupViewLayout {
    enum Constants {
        static let inputIconRadius: CGFloat = 20
    }
}
