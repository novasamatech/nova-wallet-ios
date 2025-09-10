import UIKit
import Foundation_iOS

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

    let networkContainerView = TransferNetworkContainerView()

    let recepientTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
        return label
    }()

    let yourWalletsControl: YourWalletsControl = .create {
        $0.apply(state: .hidden)
        $0.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    let recepientInputView: AccountInputView = {
        let view = AccountInputView()
        view.localizablePlaceholder = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.transferSetupRecipientInputPlaceholder()
        }
        return view
    }()

    let originFeeView: NetworkFeeInfoView = .create { view in
        view.hideInfoIcon()
    }

    private(set) var crossChainFeeView: NetworkFeeView?

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    let web3NameReceipientView = Web3NameReceipientView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

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

        let view = UIFactory.default.createNetworkFeeView()
        view.verticalOffset = 13.0
        view.title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonCrossChainFee()
        }

        containerView.stackView.addArrangedSubview(view)

        crossChainFeeView = view
    }

    func switchOnChain() {
        crossChainFeeView?.removeFromSuperview()
        crossChainFeeView = nil
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
        }

        containerView.stackView.setCustomSpacing(16.0, after: networkContainerView)

        let titleStackView = UIStackView(arrangedSubviews: [
            recepientTitleLabel,
            FlexibleSpaceView(),
            yourWalletsControl
        ])
        containerView.stackView.addArrangedSubview(titleStackView)
        containerView.stackView.setCustomSpacing(0, after: titleStackView)
        containerView.stackView.addArrangedSubview(recepientInputView)
        containerView.stackView.setCustomSpacing(8.0, after: recepientInputView)
        containerView.stackView.addArrangedSubview(web3NameReceipientView)
        containerView.stackView.setCustomSpacing(16, after: web3NameReceipientView)

        containerView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(originFeeView)
    }
}
