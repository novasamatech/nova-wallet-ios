import UIKit

final class VotingDetailsRow: RowView<ReferendumVotingStatusDetailsView> {
    let referendumVotingStatusDetailsView = ReferendumVotingStatusDetailsView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView = referendumVotingStatusDetailsView
        backgroundView = TriangularedBlurView()
        backgroundColor = .clear
    }
}
