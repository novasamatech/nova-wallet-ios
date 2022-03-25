import UIKit

final class TransferSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let tokenLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle2
        label.minimumScaleFactor = 0.5
        return label
    }()

    let networkView = WalletChainView()

    let networkContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let recepientTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        return label
    }()

    let recepientInputView: AccountInputView = {
        let view = AccountInputView()
        return view
    }()

    let networkFeeView = UIFactory.default.createNetwork26FeeView()

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        containerView.stackView.addArrangedSubview(networkContainerView)
        networkContainerView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(28.0)
        }

        networkContainerView.addSubview(tokenLabel)
        tokenLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        networkContainerView.addSubview(networkView)
        networkView.snp.makeConstraints { make in
            make.leading.equalTo(tokenLabel.snp.trailing).offset(10.0)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }

        containerView.stackView.setCustomSpacing(16.0, after: networkContainerView)

        containerView.stackView.addArrangedSubview(recepientTitleLabel)
        containerView.stackView.setCustomSpacing(8.0, after: recepientTitleLabel)
        containerView.stackView.addArrangedSubview(recepientInputView)
        containerView.stackView.setCustomSpacing(8.0, after: recepientInputView)

        containerView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }
    }
}
