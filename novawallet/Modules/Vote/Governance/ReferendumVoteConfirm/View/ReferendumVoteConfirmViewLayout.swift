import UIKit

final class ReferendumVoteConfirmViewLayout: BaseReferendumVoteConfirmViewLayout {
    let yourVoteView = YourVoteRow()

    override func setupLayout() {
        super.setupLayout()

        containerView.stackView.insertArranged(view: yourVoteView, after: feeCell)
        containerView.stackView.setCustomSpacing(12.0, after: yourVoteView)
    }
}
