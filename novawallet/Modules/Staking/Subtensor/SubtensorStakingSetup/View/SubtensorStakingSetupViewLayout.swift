import UIKit

final class SubtensorStakingSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountTitleView = SwapSetupTitleView(frame: .zero)

    let maxSkeletonView = SubtensorStakingSetupViewLayout.createSkeletonView()

    let amountInputView = NewAmountInputView()

    let getTaoCardView: SubtensorGetTaoCardView = .create { view in
        view.isHidden = true
    }

    let reserveAlertView: InlineAlertView = {
        let view = InlineAlertView.warning()
        view.isHidden = true
        return view
    }()

    let detailsTableView = StackTableView()

    let validatorCell: StackInfoTableCell = .create { cell in
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let validatorSkeletonView = SubtensorStakingSetupViewLayout.createSkeletonView()

    let apyCell: StackTableCell = .create { cell in
        cell.detailsLabel.textColor = R.color.colorTextPositive()
    }

    let apySkeletonView = SubtensorStakingSetupViewLayout.createSkeletonView()

    let networkFeeCell = StackNetworkFeeCell()

    let feeSkeletonView = SubtensorStakingSetupViewLayout.createSkeletonView()

    let sectionLabel: UILabel = .create { label in
        label.apply(style: .semiboldCaps2Secondary)
        label.isHidden = true
    }

    let pickCardView: SubtensorPickCardView = .create { view in
        view.isHidden = true
    }

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
}

private extension SubtensorStakingSetupViewLayout {
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

        containerView.stackView.addArrangedSubview(getTaoCardView)

        containerView.stackView.setCustomSpacing(12.0, after: amountInputView)
        containerView.stackView.setCustomSpacing(12.0, after: getTaoCardView)

        containerView.stackView.addArrangedSubview(reserveAlertView)
        containerView.stackView.setCustomSpacing(16.0, after: reserveAlertView)
    }

    func setupDetailsLayout() {
        containerView.stackView.addArrangedSubview(detailsTableView)

        detailsTableView.addArrangedSubview(validatorCell)
        detailsTableView.addArrangedSubview(apyCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        containerView.stackView.addArrangedSubview(sectionLabel)
        containerView.stackView.setCustomSpacing(8, after: sectionLabel)
        containerView.stackView.addArrangedSubview(pickCardView)
        containerView.stackView.setCustomSpacing(16, after: pickCardView)
        containerView.stackView.addArrangedSubview(feeDisclosureLabel)

        let skeletons: [(SubtensorChartLoadingView, UIView, CGFloat)] = [
            (validatorSkeletonView, validatorCell, 100),
            (apySkeletonView, apyCell, 80),
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
