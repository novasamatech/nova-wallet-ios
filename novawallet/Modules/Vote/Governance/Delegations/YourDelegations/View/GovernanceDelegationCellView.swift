import UIKit

typealias GovernanceTrackCountView = GenericPairValueView<BorderedIconLabelView, BorderedLabelView>

final class GovernanceDelegationCellView: GenericTitleValueView<GovernanceTrackCountView, MultiValueView> {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {}
}

extension GovernanceDelegationCellView {
    struct Track {
        let trackViewModel: ReferendumInfoView.Track
        let tracksCount: String?
    }

    struct Votes {
        let votesTitle: String
        let votesDetails: String
    }

    struct Model {
        let track: Track
        let votes: Votes
    }
}
