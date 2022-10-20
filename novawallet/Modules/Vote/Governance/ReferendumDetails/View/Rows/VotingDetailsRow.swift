import UIKit

final class VotingDetailsRow: RowView<ReferendumVotingStatusDetailsView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = true
        contentInsets = .zero
        roundedBackgroundView.apply(style: .roundedView)
        backgroundColor = .clear
    }
}
