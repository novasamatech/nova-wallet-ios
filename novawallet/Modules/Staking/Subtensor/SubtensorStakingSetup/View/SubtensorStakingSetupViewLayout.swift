import UIKit

final class SubtensorStakingSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let networkTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    let networkTableView: StackTableView = {
        let view = StackTableView()
        view.cellHeight = 44.0
        view.contentInsets = UIEdgeInsets(top: 4.0, left: 16.0, bottom: 4.0, right: 16.0)
        return view
    }()

    let networkCell = StackTableCell()
    let targetLoadingView = SubtensorChartLoadingView()

    let collatorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    let collatorTableView: StackTableView = {
        let view = StackTableView()
        view.cellHeight = 34.0
        view.contentInsets = UIEdgeInsets(top: 7.0, left: 16.0, bottom: 7.0, right: 16.0)
        return view
    }()

    let collatorActionView = StackAccountSelectionCell()

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    /// only ever populated on the root lane — the subnet lane pays in a floating token and must
    /// never carry a TAO-denominated earn headline (spec §6.3)
    let rewardsView = RewardSelectionView()

    let quoteTableView: StackTableView = {
        let view = StackTableView()
        view.cellHeight = 44.0
        view.contentInsets = UIEdgeInsets(top: 4.0, left: 16.0, bottom: 4.0, right: 16.0)
        return view
    }()

    let receiveCell = StackTableCell()

    let poolFeeCell = StackTableCell()

    let priceImpactCell = StackTableCell()

    let slippageCell = StackTableCell()

    let minStakeView = TitleAmountView.dark()

    let networkFeeView = UIFactory.default.createNetworkFeeView()

    let safetyNoteLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setQuotePanel(hidden: Bool) {
        quoteTableView.isHidden = hidden
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(networkTitleLabel)
        networkTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(networkTableView)
        networkTableView.addArrangedSubview(networkCell)

        containerView.stackView.setCustomSpacing(8.0, after: networkTableView)

        containerView.stackView.addArrangedSubview(collatorTitleLabel)
        collatorTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(collatorTableView)
        collatorTableView.addArrangedSubview(collatorActionView)

        containerView.stackView.setCustomSpacing(8.0, after: collatorTableView)

        containerView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(rewardsView)
        rewardsView.snp.makeConstraints { make in
            make.height.equalTo(56.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: rewardsView)

        containerView.stackView.addArrangedSubview(quoteTableView)
        quoteTableView.addArrangedSubview(receiveCell)
        quoteTableView.addArrangedSubview(poolFeeCell)
        quoteTableView.addArrangedSubview(priceImpactCell)
        quoteTableView.addArrangedSubview(slippageCell)

        containerView.stackView.setCustomSpacing(16.0, after: quoteTableView)

        containerView.stackView.addArrangedSubview(minStakeView)

        containerView.stackView.addArrangedSubview(networkFeeView)
        containerView.stackView.addArrangedSubview(safetyNoteLabel)

        containerView.stackView.insertArrangedSubview(amountView, at: 0)
        containerView.stackView.insertArrangedSubview(amountInputView, at: 1)
        containerView.stackView.insertArrangedSubview(targetLoadingView, at: 2)
        targetLoadingView.snp.makeConstraints { make in make.height.equalTo(260) }
        containerView.stackView.spacing = 8
        containerView.stackView.setCustomSpacing(20, after: amountInputView)
    }
}
