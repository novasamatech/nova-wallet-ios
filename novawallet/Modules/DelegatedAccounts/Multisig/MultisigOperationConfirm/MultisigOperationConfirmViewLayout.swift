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
}

// MARK: - Private

private extension MultisigOperationConfirmViewLayout {
    func setupOriginSection(with viewModel: MultisigOperationConfirmViewModel.OriginModel) {
        senderTableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

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
        containerView.stackView.setCustomSpacing(12.0, after: signatoryTableView)

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
        containerView.stackView.setCustomSpacing(12.0, after: signatoryListView)

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
}

// MARK: - SignatoryListExpandableViewDelegate

extension MultisigOperationConfirmViewLayout: SignatoryListExpandableViewDelegate {
    func didChangeState(to state: SignatoryListExpandableView.State) {
        currentSignatoryWidgetHeight = state.height

        signatoryListView.snp.updateConstraints { make in
            make.height.equalTo(state.height)
        }

        layoutChangesAnimator.animate(
            block: { [weak self] in self?.containerView.stackView.layoutIfNeeded() },
            completionBlock: nil
        )
    }
}
