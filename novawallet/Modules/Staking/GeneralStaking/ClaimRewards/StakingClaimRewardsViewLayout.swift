import UIKit

final class StakingClaimRewardsViewLayout: StakingGenericRewardsViewLayout {
    let settingsTableView: StackTableView = .create { view in
        view.cellHeight = 36
        view.contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    let restakeCell = StackSwitchCell()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(settingsTableView)
        settingsTableView.addArrangedSubview(restakeCell)
    }
}
