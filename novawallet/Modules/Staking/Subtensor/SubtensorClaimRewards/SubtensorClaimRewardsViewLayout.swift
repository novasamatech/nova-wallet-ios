import UIKit

final class SubtensorClaimRewardsViewLayout: StakingGenericRewardsViewLayout {
    let pendingCell: StackTitleMultiValueCell = .create { cell in
        cell.canSelect = false
    }

    let hintListView = HintListView()

    override func setupLayout() {
        super.setupLayout()

        walletTableView.addArrangedSubview(pendingCell)

        addArrangedSubview(hintListView)
    }
}
