import UIKit
import UIKit_iOS

final class AccountManagementHintView: UIView {
    private let iconDetailsView: IconDetailsView = .create {
        $0.stackView.alignment = .top
        $0.mode = .iconDetails
        $0.iconWidth = Constants.mainIconWidth
        $0.spacing = Constants.mainSpacing
        $0.detailsLabel.textColor = R.color.colorTextPrimary()
        $0.detailsLabel.font = .caption1
    }

    private let backgroundView: RoundedView = .create {
        $0.apply(style: .chips)
        $0.fillColor = R.color.colorBlockBackground()!
        $0.highlightedFillColor = R.color.colorBlockBackground()!
        $0.cornerRadius = Constants.cornerRadius
    }

    private let delegateView: IconDetailsView = .create {
        $0.detailsLabel.apply(style: .footnotePrimary)
        $0.iconWidth = Constants.delegateIconSize
        $0.mode = .iconDetails
        $0.spacing = Constants.delegateSpacing
    }

    private lazy var contentView = UIView.vStack(spacing: Constants.mainSpacing, [
        iconDetailsView,
        contextViewContainer
    ])

    private lazy var contextViewContainer = UIView.hStack([
        .spacer(length: Constants.contextIndentation),
        delegateViewContainer
    ])

    private lazy var delegateViewContainer = UIView.vStack(spacing: Constants.mainSpacing, [
        delegateView,
        otherSignatoriesStack
    ])

    private lazy var otherSignatoriesStack = UIView.vStack(spacing: Constants.mainSpacing, [
        otherSignatoriesLabel
    ])

    let otherSignatoriesLabel: UILabel = .create {
        $0.font = .caption1
        $0.textColor = R.color.colorTextSecondary()
    }

    let contentInsets = UIEdgeInsets(
        top: Constants.contentInsetValue,
        left: Constants.contentInsetValue,
        bottom: Constants.contentInsetValue,
        right: Constants.contentInsetValue
    )

    private var delegateIcon: ImageViewModelProtocol?
    private var otherSignatoryIcons: [ImageViewModelProtocol] = []

    private var signatoryInfoClosure: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension AccountManagementHintView {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        otherSignatoriesLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.otherSignatoriesLabelHeight)
        }

        delegateView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.delegateViewHeight)
        }

        contextViewContainer.isHidden = true
        otherSignatoriesStack.isHidden = true
    }

    func bindDelegate(viewModel: AccountDelegateViewModel) {
        contextViewContainer.isHidden = false

        delegateView.detailsLabel.attributedText = viewModel.name

        delegateIcon?.cancel(on: delegateView.imageView)

        viewModel.icon?.loadImage(
            on: delegateView.imageView,
            targetSize: .init(width: Constants.delegateIconSize, height: Constants.delegateIconSize),
            animated: true
        )

        delegateIcon = viewModel.icon
    }

    func bindMultisigContext(
        context: AccountManageWalletViewModel.WalletContext.Multisig
    ) {
        signatoryInfoClosure = context.signatoryInfoClosure

        configureOtherSignatories(
            context.otherSignatories,
            title: context.otherSignatoriesTitle
        )
    }

    func configureOtherSignatories(
        _ signatories: [WalletInfoView<WalletView>.ViewModel],
        title: String
    ) {
        otherSignatoryIcons.removeAll()
        otherSignatoriesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        otherSignatoriesStack.isHidden = signatories.isEmpty

        guard !signatories.isEmpty else { return }

        for signatory in signatories {
            let signatoryView = createOtherSignatoryView(for: signatory)
            otherSignatoriesStack.addArrangedSubview(signatoryView)
        }

        otherSignatoriesLabel.text = title
        otherSignatoriesStack.insertArrangedSubview(otherSignatoriesLabel, at: 0)

        contentView.layoutIfNeeded()
    }

    func createOtherSignatoryView(for signatory: WalletInfoView<WalletView>.ViewModel) -> UIView {
        let walletInfoControl = WalletInfoControl()
        walletInfoControl.preferredHeight = Constants.signatoryControlPreferredHeight
        walletInfoControl.rowContentView.walletView.iconTitleSpacing = Constants.signatoryIconTitleSpacing
        walletInfoControl.rowContentView.spacing = Constants.signatoryRowSpacing
        walletInfoControl.contentInsets = .zero
        walletInfoControl.changesContentOpacityWhenHighlighted = true
        walletInfoControl.roundedBackgroundView?.highlightedFillColor = .clear
        walletInfoControl.rowContentView.walletView.titleLabel.lineBreakMode = signatory.wallet.lineBreakMode
        walletInfoControl.rowContentView.walletView.titleLabel.apply(style: .footnoteSecondary)
        walletInfoControl.borderView.strokeColor = .clear

        walletInfoControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.signatoryViewHeight)
        }
        walletInfoControl.rowContentView.iconImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.signatoryIconSize)
        }
        walletInfoControl.rowContentView.iconContainerView.snp.makeConstraints { make in
            make.size.equalTo(Constants.signatoryIconSize)
        }

        walletInfoControl.bind(viewModel: signatory)

        walletInfoControl.addTarget(
            self,
            action: #selector(actionSignatoryInfo(sender:)),
            for: .touchUpInside
        )

        return walletInfoControl
    }

    @objc func actionSignatoryInfo(sender: UIControl) {
        guard
            let control = sender as? WalletInfoControl,
            let address = control.rowContentView.walletView.viewModel?.wallet.name
        else { return }

        signatoryInfoClosure?(address)
    }
}

// MARK: - Internal

extension AccountManagementHintView {
    func bindHint(text: String, icon: UIImage?) {
        contextViewContainer.isHidden = true

        iconDetailsView.detailsLabel.text = text
        iconDetailsView.imageView.image = icon
    }

    func bindDelegatedWalletContext(_ context: AccountManageWalletViewModel.WalletContext) {
        switch context {
        case let .multisig(multisigContext):
            bindDelegate(viewModel: multisigContext.signatory)
            bindMultisigContext(context: multisigContext)
        case let .proxied(proxiedContext):
            bindDelegate(viewModel: proxiedContext.proxy)
        }
    }
}

// MARK: - Constants

private extension AccountManagementHintView {
    enum Constants {
        static let mainIconWidth: CGFloat = 20.0
        static let delegateIconSize: CGFloat = 16.0
        static let signatoryIconSize: CGFloat = 16.0

        static let mainSpacing: CGFloat = 12.0
        static let delegateSpacing: CGFloat = 4.0
        static let signatorySpacing: CGFloat = 4.0

        static let cornerRadius: CGFloat = 12.0
        static let contentInsetValue: CGFloat = 12.0
        static let contextIndentation: CGFloat = 32.0

        static let delegateViewHeight: CGFloat = 18.0
        static let signatoryViewHeight: CGFloat = 18.0
        static let otherSignatoriesLabelHeight: CGFloat = 16.0

        static let signatoryControlPreferredHeight: CGFloat = 18.0
        static let signatoryIconTitleSpacing: CGFloat = 4.0
        static let signatoryRowSpacing: CGFloat = 4.0
    }
}
