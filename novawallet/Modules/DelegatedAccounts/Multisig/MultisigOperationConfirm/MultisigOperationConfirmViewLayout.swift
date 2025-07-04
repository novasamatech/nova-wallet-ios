import UIKit
import UIKit_iOS

final class MultisigOperationConfirmViewLayout: ScrollableContainerLayoutView {
    let amountView = MultilineBalanceView()

    private let layoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        options: [.curveEaseInOut]
    )

    private var currentSignatoryWidgetHeight = SignatoryListExpandableView.Constants.collapsedStateHeight

    // MARK: - Sender

    let senderTableView = StackTableView()

    let originNetworkCell = StackNetworkCell()

    let multisigWalletCell = StackInfoTableCell()

    let onBehalfOfCell: StackInfoTableCell = .create { view in
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    // MARK: - Recipient

    let recepientTableView = StackTableView()

    let destinationNetworkCell = StackNetworkCell()

    let recepientCell: StackInfoTableCell = .create { view in
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    // MARK: - Signatory

    let signatoryTableView = StackTableView()

    let signatoryWalletCell = StackInfoTableCell()

    let feeCell = StackNetworkFeeCell()

    // MARK: - SignatoryList

    lazy var signatoryListView: SignatoryListExpandableView = .create { view in
        view.delegate = self
    }

    // MARK: - Actions

    private lazy var buttonsStack: UIStackView = .vStack(
        spacing: Constants.interButtonSpacing,
        [callDataButton, confirmButton]
    )

    let callDataButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
        button.changesContentOpacityWhenHighlighted = true
        button.isHidden = true
    }

    let confirmButton: LoadableActionView = .create { button in
        button.actionButton.applyDefaultStyle()
        button.actionButton.changesContentOpacityWhenHighlighted = true
        button.isHidden = true
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(buttonsStack)

        buttonsStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        [callDataButton, confirmButton].forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }
    }
}

// MARK: - Private

private extension MultisigOperationConfirmViewLayout {
    func setupOriginSection(with viewModel: MultisigOperationConfirmViewModel.OriginModel) {
        senderTableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(Constants.interSectionSpacing, after: senderTableView)

        senderTableView.addArrangedSubview(originNetworkCell)
        senderTableView.addArrangedSubview(multisigWalletCell)

        originNetworkCell.titleLabel.text = viewModel.network.title
        originNetworkCell.bind(viewModel: viewModel.network.value)

        multisigWalletCell.titleLabel.text = viewModel.wallet.title
        multisigWalletCell.bind(viewModel: viewModel.wallet.value)
    }

    func setupSignatorySection(with viewModel: MultisigOperationConfirmViewModel.SignatoryModel) {
        signatoryTableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        containerView.stackView.addArrangedSubview(signatoryTableView)
        containerView.stackView.setCustomSpacing(Constants.interSectionSpacing, after: signatoryTableView)

        signatoryTableView.addArrangedSubview(signatoryWalletCell)
        signatoryTableView.addArrangedSubview(feeCell)

        signatoryWalletCell.titleLabel.text = viewModel.wallet.title
        signatoryWalletCell.bind(viewModel: viewModel.wallet.value)

        feeCell.rowContentView.titleLabel.text = viewModel.fee.title
        feeCell.rowContentView.bind(viewModel: viewModel.fee.value)
    }

    func setupAllSignatoriesSection(with viewModel: MultisigOperationConfirmViewModel.SignatoriesModel) {
        signatoryListView.snp.makeConstraints { make in
            make.height.equalTo(signatoryListView.state.height)
        }

        containerView.stackView.addArrangedSubview(signatoryListView)
        containerView.stackView.setCustomSpacing(Constants.interSectionSpacing, after: signatoryListView)

        signatoryListView.titleLabel.text = viewModel.signatories.title
        signatoryListView.bind(with: viewModel.signatories.value)
    }
}

// MARK: - Internal

extension MultisigOperationConfirmViewLayout {
    func bind(viewModel: MultisigOperationConfirmViewModel) {
        containerView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        viewModel.sections.forEach { section in
            switch section {
            case let .origin(originModel):
                setupOriginSection(with: originModel)
            case let .signatory(signatoryModel):
                setupSignatorySection(with: signatoryModel)
            case let .signatories(signatoriesModel):
                setupAllSignatoriesSection(with: signatoriesModel)
            default:
                break
            }
        }
    }

    func bind(fee viewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>) {
        feeCell.rowContentView.titleLabel.text = viewModel.title
        feeCell.rowContentView.bind(viewModel: viewModel.value)
    }

    func bindReject(title: String) {
        confirmButton.actionButton.imageWithTitleView?.title = title
        confirmButton.actionButton.applyDestructiveEnabledStyle()
        confirmButton.isHidden = false
    }

    func bindApprove(title: String) {
        confirmButton.actionButton.imageWithTitleView?.title = title
        confirmButton.actionButton.applyDefaultStyle()
        confirmButton.isHidden = false
    }

    func bindCallDataButton(title: String) {
        callDataButton.imageWithTitleView?.title = title
        callDataButton.isHidden = false
    }
}

// MARK: - SignatoryListExpandableViewDelegate

extension MultisigOperationConfirmViewLayout: SignatoryListExpandableViewDelegate {
    func didChangeState(to state: SignatoryListExpandableView.State) {
        currentSignatoryWidgetHeight = state.height

        signatoryListView.snp.remakeConstraints { make in
            make.height.equalTo(state.height)
        }

        layoutChangesAnimator.animate(
            block: { [weak self] in
                self?.containerView.layoutIfNeeded()
            },
            completionBlock: nil
        )
    }
}

// MARK: - Constants

private extension MultisigOperationConfirmViewLayout {
    enum Constants {
        static let interSectionSpacing: CGFloat = 12.0
        static let interButtonSpacing: CGFloat = 16.0
    }
}
