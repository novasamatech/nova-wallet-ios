import UIKit

final class NPoolsClaimRewardsViewLayout: SCLoadableActionLayoutView {
    let amountView = MultilineBalanceView()

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    let settingsTableView: StackTableView = .create { view in
        view.cellHeight = 36
        view.contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    let restakeCell = StackSwitchCell()

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

        addArrangedSubview(settingsTableView)
        settingsTableView.addArrangedSubview(restakeCell)
    }
}
