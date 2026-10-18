import UIKit

final class SubtensorUnstakeSetupLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountTitleView = SwapSetupTitleView(frame: .zero)

    let maxSkeletonView = SubtensorUnstakeSetupLayout.createSkeletonView()

    let amountInputView = NewAmountInputView()

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

    let validatorSkeletonView = SubtensorUnstakeSetupLayout.createSkeletonView()

    let subnetValidatorCell: SubtensorValidatorDetailsCell = .create { cell in
        cell.rowContentView.bind(apy: nil)
    }

    let subnetValidatorSkeletonView = SubtensorUnstakeSetupLayout.createSkeletonView()

    let networkFeeCell = StackNetworkFeeCell()

    let feeSkeletonView = SubtensorUnstakeSetupLayout.createSkeletonView()

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

    let feeDisclosureLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let holdAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let captionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let actionButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSkeleton(_ skeletonView: SubtensorChartLoadingView, loading: Bool, hiding view: UIView) {
        skeletonView.setLoading(loading)
        view.alpha = loading ? 0 : 1
    }

    func setupMode(isRoot: Bool) {
        validatorCell.isHidden = !isRoot
        subnetValidatorCell.isHidden = isRoot
        detailsTableView.updateLayout()
    }
}

private extension SubtensorUnstakeSetupLayout {
    static func createSkeletonView() -> SubtensorChartLoadingView {
        let view = SubtensorChartLoadingView()
        view.layer.cornerRadius = 6
        return view
    }

    func setupLayout() {
        let bottomStack = UIView.vStack(spacing: 16, [holdAlertView, captionLabel, actionButton])
        bottomStack.setCustomSpacing(12, after: holdAlertView)

        addSubview(bottomStack)
        bottomStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomStack.snp.top).offset(-8.0)
        }

        setupAmountLayout()
        setupDetailsLayout()
    }

    func setupAmountLayout() {
        containerView.stackView.addArrangedSubview(amountTitleView)
        amountTitleView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        amountTitleView.addSubview(maxSkeletonView)
        maxSkeletonView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 90, height: 12))
        }

        containerView.stackView.setCustomSpacing(8.0, after: amountTitleView)

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)
    }

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
        containerView.stackView.addArrangedSubview(feeDisclosureLabel)

        let skeletons: [(SubtensorChartLoadingView, UIView, CGFloat)] = [
            (validatorSkeletonView, validatorCell, 100),
            (subnetValidatorSkeletonView, subnetValidatorCell, 100),
            (feeSkeletonView, networkFeeCell, 70)
        ]

        skeletons.forEach { skeletonView, cell, width in
            cell.addSubview(skeletonView)
            skeletonView.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(16)
                make.centerY.equalToSuperview()
                make.size.equalTo(CGSize(width: width, height: 12))
            }
        }
    }
}
