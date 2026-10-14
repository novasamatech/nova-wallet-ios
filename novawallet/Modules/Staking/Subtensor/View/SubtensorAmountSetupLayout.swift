import UIKit

class SubtensorAmountSetupLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountTitleView = SwapSetupTitleView(frame: .zero)

    let maxSkeletonView = SubtensorAmountSetupLayout.createSkeletonView()

    let amountInputView = NewAmountInputView()

    let networkFeeCell = StackNetworkFeeCell()

    let feeSkeletonView = SubtensorAmountSetupLayout.createSkeletonView()

    let captionLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let bottomStack: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = 16
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

    static func createSkeletonView() -> SubtensorChartLoadingView {
        let view = SubtensorChartLoadingView()
        view.layer.cornerRadius = 6
        return view
    }

    func setSkeleton(_ skeletonView: SubtensorChartLoadingView, loading: Bool, hiding view: UIView) {
        skeletonView.setLoading(loading)
        view.alpha = loading ? 0 : 1
    }

    func addSkeleton(_ skeletonView: SubtensorChartLoadingView, to cell: UIView, width: CGFloat) {
        cell.addSubview(skeletonView)
        skeletonView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: width, height: 12))
        }
    }

    func applyNetworkFee(_ viewModel: BalanceViewModelProtocol?) {
        let feeView: NetworkFeeView = networkFeeCell.rowContentView

        feeView.bind(viewModel: viewModel ?? BalanceViewModel(amount: "", price: nil))
        setSkeleton(feeSkeletonView, loading: viewModel == nil, hiding: feeView.tokenLabel)
    }

    func applyAction(_ viewModel: SubtensorSetupActionViewModel) {
        if viewModel.isEnabled {
            actionButton.applyEnabledStyle()
        } else {
            actionButton.applyDisabledStyle()
        }

        actionButton.isUserInteractionEnabled = viewModel.isEnabled
        actionButton.imageWithTitleView?.title = viewModel.title
        actionButton.invalidateLayout()
    }

    func setupLayout() {
        bottomStack.addArrangedSubview(captionLabel)
        bottomStack.addArrangedSubview(actionButton)

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

        addSkeleton(feeSkeletonView, to: networkFeeCell, width: 70)
    }
}
