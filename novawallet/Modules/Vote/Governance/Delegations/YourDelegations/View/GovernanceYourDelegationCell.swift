import Foundation

final class GovernanceYourDelegationCell: UITableViewCell {}

extension GovernanceYourDelegationCell {
    struct Model {
        let delegateViewModel: GovernanceDelegateTableViewCell.Model
        let delegationViewModel: GovernanceDelegationCellView.Model
    }
}
