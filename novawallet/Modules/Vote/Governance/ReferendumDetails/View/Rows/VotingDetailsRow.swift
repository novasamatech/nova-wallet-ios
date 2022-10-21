import UIKit

final class VotingDetailsRow: RowView<ReferendumVotingStatusDetailsView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        contentInsets = .zero
        roundedBackgroundView.apply(style: .cellWithoutHighlighting)
        backgroundColor = .clear
    }
}
