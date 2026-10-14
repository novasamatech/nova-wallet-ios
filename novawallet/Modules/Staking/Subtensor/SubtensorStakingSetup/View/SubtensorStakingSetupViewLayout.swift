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

    let selectionAlert: InlineAlertView = .create { $0.isHidden = true }
    let browseButton = UIButton(type: .system)

    let detailsTableView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
        $0.layer.cornerRadius = 12
    }

    let validatorCardView: SubtensorValidatorCardView = .create { $0.applyEmbeddedStyle() }
    let rootPickCardView: SubtensorRootPickCardView = .create { $0.isHidden = true }

    let networkFeeCell = StackNetworkFeeCell()

    let feeSkeletonView = SubtensorStakingSetupViewLayout.createSkeletonView()

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

    let captionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    private let bottomStack = UIStackView()

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

    func placeCaption(afterAction: Bool) {
        bottomStack.removeArrangedSubview(captionLabel)
        bottomStack.insertArrangedSubview(captionLabel, at: afterAction ? 1 : 0)
    }

    func setSkeleton(_ skeletonView: SubtensorChartLoadingView, loading: Bool, hiding view: UIView) {
        skeletonView.setLoading(loading)
        view.alpha = loading ? 0 : 1
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

    static func createSkeletonView() -> SubtensorChartLoadingView {
        let view = SubtensorChartLoadingView()
        view.layer.cornerRadius = 6
        return view
    }

    func setupLayout() {
        bottomStack.axis = .vertical
        bottomStack.spacing = 16
        bottomStack.addArrangedSubview(actionButton)
        bottomStack.addArrangedSubview(captionLabel)

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

        let skeletons: [(SubtensorChartLoadingView, UIView, CGFloat)] = [
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
