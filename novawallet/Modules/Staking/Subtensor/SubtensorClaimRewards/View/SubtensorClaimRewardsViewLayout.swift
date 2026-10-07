import UIKit

final class SubtensorClaimRewardsViewLayout: StakingGenericRewardsViewLayout {
    let detailsTableView = StackTableView()

    let validatorCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let stakeAfterCell = StackTableCell()

    let noticeView = InlineAlertView.info()

    let signingHintView: AccountManagementHintView = .create {
        $0.isHidden = true
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(detailsTableView, spacingAfter: 12)

        detailsTableView.addArrangedSubview(validatorCell)
        detailsTableView.addArrangedSubview(stakeAfterCell)

        addArrangedSubview(noticeView, spacingAfter: 12)
        addArrangedSubview(signingHintView)
    }
}
