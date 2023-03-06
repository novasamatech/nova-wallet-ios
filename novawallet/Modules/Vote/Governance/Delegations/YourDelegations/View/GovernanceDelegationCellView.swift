import UIKit

typealias GovernanceTrackCountView = GenericPairValueView<BorderedIconLabelView, BorderedLabelView>

final class GovernanceDelegationCellView: GenericTitleValueView<GovernanceTrackCountView, MultiValueView> {
    var tracksView: BorderedIconLabelView {
        titleView.fView
    }

    var tracksCountView: BorderedLabelView {
        titleView.sView
    }

    var votesTitleLabel: UILabel {
        valueView.valueTop
    }

    var votesDetailsLabel: UILabel {
        valueView.valueBottom
    }

    private var tracksImageViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        tracksView.iconDetailsView.spacing = 6
        tracksView.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        tracksView.iconDetailsView.detailsLabel.numberOfLines = 1
        tracksView.apply(style: .track)

        tracksCountView.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
        tracksCountView.backgroundView.cornerRadius = 6
        tracksCountView.apply(style: .chipsText)

        titleView.makeHorizontal()
        titleView.spacing = 4

        votesTitleLabel.apply(style: .footnotePrimary)
        votesDetailsLabel.apply(style: .footnoteSecondary)
    }

    func bind(viewModel: Model) {
        tracksView.iconDetailsView.detailsLabel.text = viewModel.track.trackViewModel.title

        tracksImageViewModel?.cancel(on: tracksView.iconDetailsView.imageView)
        tracksImageViewModel = viewModel.track.trackViewModel.icon

        tracksImageViewModel?.loadImage(
            on: tracksView.iconDetailsView.imageView,
            targetSize: CGSize(width: 16, height: 16),
            animated: true
        )

        if let tracksCount = viewModel.track.tracksCount {
            tracksCountView.isHidden = false

            tracksCountView.titleLabel.text = tracksCount
        } else {
            tracksCountView.isHidden = true
        }

        votesTitleLabel.text = viewModel.votes.votesTitle
        votesDetailsLabel.text = viewModel.votes.votesDetails
    }
}

extension GovernanceDelegationCellView {
    struct Track: Hashable {
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.trackViewModel.title == rhs.trackViewModel.title && lhs.tracksCount == rhs.tracksCount
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(trackViewModel.title)
            hasher.combine(tracksCount)
        }

        let trackViewModel: ReferendumInfoView.Track
        let tracksCount: String?
    }

    struct Votes: Hashable {
        let votesTitle: String
        let votesDetails: String
    }

    struct Model: Hashable {
        let track: Track
        let votes: Votes
    }
}
