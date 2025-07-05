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

    let delegatedAccountCell = StackInfoTableCell()

    // MARK: - Recipient

    let recipientTableView = StackTableView()

    let recipientCell = StackInfoTableCell()

    // MARK: - Signatory

    let signatoryTableView = StackTableView()

    let signatoryWalletCell = StackInfoTableCell()

    let feeCell = StackNetworkFeeCell()

    // MARK: - SignatoryList

    lazy var signatoryListView: SignatoryListExpandableView = .create { view in
        view.delegate = self
    }

    // MARK: - Full details

    let fullDetailsTableView = StackTableView()

    let fullDetailsCell: StackActionCell = .create { view in
        view.rowContentView.disclosureIndicatorView.image = R.image.iconSmallArrow()?
            .tinted(with: R.color.colorIconSecondary()!)
        view.rowContentView.iconSize = .zero
        view.titleLabel.textColor = R.color.colorButtonTextAccent()
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
        prepareTableView(senderTableView)

        senderTableView.addArrangedSubview(originNetworkCell)
        senderTableView.addArrangedSubview(multisigWalletCell)

        originNetworkCell.titleLabel.text = viewModel.network.title
        originNetworkCell.bind(viewModel: viewModel.network.value)

        multisigWalletCell.titleLabel.text = viewModel.wallet.title
        multisigWalletCell.bind(viewModel: viewModel.wallet.value)

        if let delegatedAccount = viewModel.delegatedAccount {
            senderTableView.addArrangedSubview(delegatedAccountCell)
            delegatedAccountCell.titleLabel.text = delegatedAccount.title
            delegatedAccountCell.detailsLabel.lineBreakMode = delegatedAccount.value.lineBreakMode
            delegatedAccountCell.bind(viewModel: delegatedAccount.value.cellViewModel)
        }
    }

    func setupRecipientSection(with viewModel: MultisigOperationConfirmViewModel.RecipientModel) {
        prepareTableView(recipientTableView)

        recipientTableView.addArrangedSubview(recipientCell)

        recipientCell.titleLabel.text = viewModel.recipient.title
        recipientCell.detailsLabel.lineBreakMode = viewModel.recipient.value.lineBreakMode
        recipientCell.bind(viewModel: viewModel.recipient.value.cellViewModel)
    }

    func setupSignatorySection(with viewModel: MultisigOperationConfirmViewModel.SignatoryModel) {
        prepareTableView(signatoryTableView)

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

    func setupFullDetailsSection(with viewModel: MultisigOperationConfirmViewModel.FullDetailsModel) {
        prepareTableView(fullDetailsTableView)

        fullDetailsTableView.addArrangedSubview(fullDetailsCell)

        fullDetailsCell.bind(title: viewModel.title, icon: nil, details: nil)
    }

    func prepareTableView(_ tableView: StackTableView) {
        tableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        containerView.stackView.addArrangedSubview(tableView)
        containerView.stackView.setCustomSpacing(Constants.interSectionSpacing, after: tableView)
    }
}

// MARK: - Internal

extension MultisigOperationConfirmViewLayout {
    func bind(viewModel: MultisigOperationConfirmViewModel) {
        containerView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let amount = viewModel.amount {
            containerView.stackView.addArrangedSubview(amountView)
            containerView.stackView.setCustomSpacing(20.0, after: amountView)

            amountView.bind(viewModel: amount)
        }

        viewModel.sections.forEach { section in
            switch section {
            case let .origin(originModel):
                setupOriginSection(with: originModel)
            case let .recipient(recipientModel):
                setupRecipientSection(with: recipientModel)
            case let .signatory(signatoryModel):
                setupSignatorySection(with: signatoryModel)
            case let .signatories(signatoriesModel):
                setupAllSignatoriesSection(with: signatoriesModel)
            case let .fullDetails(fullDetailsModel):
                setupFullDetailsSection(with: fullDetailsModel)
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

    func bindCallDataButton(_ title: String?) {
        if let title {
            callDataButton.imageWithTitleView?.title = title
            callDataButton.isHidden = false
        } else {
            callDataButton.isHidden = true
        }
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
        static let interSectionSpacing: CGFloat = 8.0
        static let interButtonSpacing: CGFloat = 16.0
    }
}
