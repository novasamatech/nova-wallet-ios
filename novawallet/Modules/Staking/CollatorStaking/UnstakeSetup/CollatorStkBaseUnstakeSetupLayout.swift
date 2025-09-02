import UIKit

class CollatorStkBaseUnstakeSetupLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

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

    let minStakeView = TitleAmountView.dark()

    let transferableView = TitleAmountView.dark()

    let networkFeeView = UIFactory.default.createNetworkFeeView()

    let hintListView = HintListView()

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

    func setupLayout() {
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

        containerView.stackView.addArrangedSubview(minStakeView)

        containerView.stackView.addArrangedSubview(transferableView)

        containerView.stackView.addArrangedSubview(networkFeeView)

        containerView.stackView.setCustomSpacing(24.0, after: networkFeeView)

        containerView.stackView.addArrangedSubview(hintListView)
    }
}
