import UIKit

final class StartStakingConfirmViewLayout: SCLoadableActionLayoutView {
    let amountView = MultilineBalanceView()

    let senderTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let feeCell = StackNetworkFeeCell()

    let stakingTableView = StackTableView()
    let stakingTypeCell = StackTableCell()

    let stakingDetailsCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 24)

        addArrangedSubview(senderTableView, spacingAfter: 8)
        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(accountCell)
        senderTableView.addArrangedSubview(feeCell)

        addArrangedSubview(stakingTableView)
        stakingTableView.addArrangedSubview(stakingTypeCell)
        stakingTableView.addArrangedSubview(stakingDetailsCell)
    }
}
