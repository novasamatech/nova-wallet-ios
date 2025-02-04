import UIKit

class StakingGenericRewardsViewLayout: SCLoadableActionLayoutView {
    let amountView = MultilineBalanceView()

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    var actionButton: TriangularedButton {
        genericActionView.actionButton
    }

    var loadingView: LoadableActionView {
        genericActionView
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 24)

        addArrangedSubview(walletTableView, spacingAfter: 12)

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)
    }
}
