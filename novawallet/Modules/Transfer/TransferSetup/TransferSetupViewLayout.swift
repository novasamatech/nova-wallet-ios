import UIKit
import SoraFoundation

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

    let originLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle2
        label.minimumScaleFactor = 0.5
        return label
    }()

    let destinationLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle2
        label.minimumScaleFactor = 0.5
        return label
    }()

    let originNetworkView = WalletChainView()

    let destinationNetworkView = WalletChainControlView()

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

    let originFeeView = UIFactory.default.createNetwork26FeeView()
    private(set) var crossChainFeeView: NetworkFeeView?

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

    func switchCrossChain() {
        guard crossChainFeeView == nil else {
            return
        }

        let view = UIFactory.default.createNetwork26FeeView()
        view.title = LocalizableResource { locale in
            R.string.localizable.commonCrossChainFee(preferredLanguages: locale.rLanguages)
        }

        containerView.stackView.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }

        crossChainFeeView = view
    }

    func switchOnChain() {
        crossChainFeeView?.removeFromSuperview()
        crossChainFeeView = nil
    }

    // swiftlint:disable:next function_body_length
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
        }

        networkContainerView.addSubview(originLabel)
        originLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().offset(8.0)
        }

        networkContainerView.addSubview(originNetworkView)
        originNetworkView.snp.makeConstraints { make in
            make.leading.equalTo(originLabel.snp.trailing).offset(10.0)
            make.centerY.equalTo(originLabel)
            make.trailing.lessThanOrEqualToSuperview()
        }

        networkContainerView.addSubview(destinationLabel)
        destinationLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(originLabel.snp.bottom).offset(4.0)
            make.bottom.equalToSuperview().offset(8.0)
        }

        networkContainerView.addSubview(destinationNetworkView)
        destinationNetworkView.snp.makeConstraints { make in
            make.leading.equalTo(destinationLabel.snp.trailing).offset(10.0)
            make.centerY.equalTo(destinationLabel)
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

        containerView.stackView.addArrangedSubview(originFeeView)
        originFeeView.snp.makeConstraints { make in
            make.height.equalTo(64.0)
        }
    }
}
