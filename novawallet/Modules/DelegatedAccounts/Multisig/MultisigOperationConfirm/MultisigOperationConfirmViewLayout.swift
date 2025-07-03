import UIKit
import UIKit_iOS

final class MultisigOperationConfirmViewLayout: ScrollableContainerLayoutView {
    let amountView = MultilineBalanceView()

    private let layoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        options: [.curveEaseInOut]
    )

    // MARK: - Sender

    let senderTableView = StackTableView()

    let originNetworkCell = StackNetworkCell()

    let multisigWalletCell = StackTableCell()

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

    let signatoryListView = SignatoryListExpandableView()
}

// MARK: - Private

private extension MultisigOperationConfirmViewLayout {}

// MARK: - Internal

extension MultisigOperationConfirmViewLayout {
    func setupConfirmationLayout() {
        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.setCustomSpacing(24.0, after: amountView)

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(originNetworkCell)
        senderTableView.addArrangedSubview(multisigWalletCell)

        containerView.stackView.addArrangedSubview(recepientTableView)
        recepientTableView.addArrangedSubview(destinationNetworkCell)
        recepientTableView.addArrangedSubview(recepientCell)

        containerView.stackView.addArrangedSubview(signatoryTableView)
        recepientTableView.addArrangedSubview(signatoryWalletCell)
        recepientTableView.addArrangedSubview(feeCell)
    }

    func setupDetailsLayout() {
        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.setCustomSpacing(24.0, after: amountView)

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(originNetworkCell)
        senderTableView.addArrangedSubview(multisigWalletCell)

        containerView.stackView.addArrangedSubview(recepientTableView)
        recepientTableView.addArrangedSubview(destinationNetworkCell)
        recepientTableView.addArrangedSubview(recepientCell)
    }
}
