import UIKit

final class VotingDetailsRow: RowView<ReferendumVotingStatusDetailsView> {
    let referendumVotingStatusDetailsView = ReferendumVotingStatusDetailsView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView = referendumVotingStatusDetailsView
        backgroundView = TriangularedBlurView()
        contentInsets = .init(top: 16, left: 16, bottom: 20, right: 16)
        backgroundColor = .clear
    }
}
