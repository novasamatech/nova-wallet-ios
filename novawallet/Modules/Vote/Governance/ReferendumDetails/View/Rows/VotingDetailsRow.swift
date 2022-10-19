import UIKit

final class VotingDetailsRow: RowView<ReferendumVotingStatusDetailsView> {
    let referendumVotingStatusDetailsView = ReferendumVotingStatusDetailsView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView = referendumVotingStatusDetailsView
        contentInsets = .zero
        backgroundView = TriangularedBlurView()
        backgroundColor = .clear
    }
}
