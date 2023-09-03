import UIKit

final class NominationPoolBondMoreConfirmViewLayout: SCLoadableActionLayoutView {
    let amountView = MultilineBalanceView()

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let networkFeeCell = StackNetworkFeeCell()

    var actionButton: TriangularedButton {
        genericActionView.actionButton
    }

    var loadingView: LoadableActionView {
        genericActionView
    }

    let hintListView = HintListView()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 24)

        addArrangedSubview(walletTableView, spacingAfter: 16)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)

        addArrangedSubview(hintListView)
    }
}
