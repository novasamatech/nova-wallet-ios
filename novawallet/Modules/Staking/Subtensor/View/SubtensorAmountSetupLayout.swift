import SnapKit
import UIKit

class SubtensorAmountSetupLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 26.0, left: 16.0, bottom: 16.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let amountTitleView: SwapSetupTitleView = .create { view in
        view.titleLabel.apply(style: .regularSubhedlineSecondary)
        view.buttonTitle.apply(style: .regularSubhedlineAccent)
        view.buttonValue.apply(style: .regularSubhedlinePrimary)
    }

    let maxSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    let amountInputView = NewAmountInputView()

    let networkFeeCell = StackNetworkFeeCell()

    let feeSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
    }

    let bottomStack: UIStackView = .create { view in
        view.axis = .vertical
        view.spacing = Constants.bottomStackSpacing
    }

    let bottomPanel = SubtensorBottomPanelView()

    let actionLoadableView = LoadableActionView()

    var actionButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    private var bottomStackConstraint: Constraint?
    private var scrollBottomConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSkeleton(_ skeletonView: SubtensorSkeletonView, loading: Bool, hiding view: UIView) {
        skeletonView.setLoading(loading)
        view.alpha = loading ? 0 : 1
    }

    func addSkeleton(_ skeletonView: SubtensorSkeletonView, to cell: UIView, width: CGFloat) {
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

    func applyCaption(_ caption: String?) {
        captionLabel.isHidden = caption == nil
        captionLabel.apply(text: caption ?? "", lineHeight: Constants.captionLineHeight)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        let hasBottomContent = bottomStack.arrangedSubviews.contains { !$0.isHidden }
        let panelSpacing = captionLabel.isHidden ? Constants.alertToPanelSpacing : Constants.captionToPanelSpacing

        bottomStackConstraint?.update(offset: hasBottomContent ? -panelSpacing : 0)
        scrollBottomConstraint?.update(offset: hasBottomContent ? -Constants.scrollToStackSpacing : 0)

        super.layoutSubviews()
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
        addSubview(containerView)

        bottomPanel.contentView.addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(bottomPanel)
        bottomPanel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        bottomStack.addArrangedSubview(captionLabel)

        addSubview(bottomStack)
        bottomStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            bottomStackConstraint = make.bottom.equalTo(bottomPanel.snp.top).constraint
        }

        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            scrollBottomConstraint = make.bottom.equalTo(bottomStack.snp.top).constraint
        }

        containerView.stackView.addArrangedSubview(amountTitleView)
        amountTitleView.snp.makeConstraints { make in
            make.height.equalTo(28.0)
        }

        amountTitleView.addSubview(maxSkeletonView)
        maxSkeletonView.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 90, height: 12))
        }

        containerView.stackView.setCustomSpacing(4.0, after: amountTitleView)

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }

        addSkeleton(feeSkeletonView, to: networkFeeCell, width: 70)
    }
}

private extension SubtensorAmountSetupLayout {
    enum Constants {
        static let bottomStackSpacing: CGFloat = 12
        static let captionToPanelSpacing: CGFloat = 8
        static let alertToPanelSpacing: CGFloat = 12
        static let scrollToStackSpacing: CGFloat = 8
        static let captionLineHeight: CGFloat = 18
    }
}
