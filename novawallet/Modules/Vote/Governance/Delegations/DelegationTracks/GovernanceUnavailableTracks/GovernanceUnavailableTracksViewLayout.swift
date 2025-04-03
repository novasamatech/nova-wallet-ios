import UIKit
import UIKit_iOS

final class GovernanceUnavailableTracksViewLayout: UIView {
    private enum Constants {
        static let contentInsets = UIEdgeInsets(top: 10, left: 16, bottom: 0, right: 16)
        static let tracksOffset: CGFloat = 10
        static let actionOffset: CGFloat = 8
        static let sectionInset: CGFloat = 19
        static let trackSpacing: CGFloat = 22
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = Constants.contentInsets
        view.stackView.alignment = .leading
        return view
    }()

    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    private(set) var delegatedTracksTitleLabel: UILabel?
    private(set) var votedTracksTitleLabel: UILabel?
    private(set) var removeVotesButton: RoundedButton?
    private var trackViews: [BorderedIconLabelView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func removeTracks() {
        delegatedTracksTitleLabel?.removeFromSuperview()
        delegatedTracksTitleLabel = nil

        votedTracksTitleLabel?.removeFromSuperview()
        votedTracksTitleLabel = nil

        removeVotesButton?.removeFromSuperview()
        removeVotesButton = nil

        trackViews.forEach { $0.removeFromSuperview() }
        trackViews = []
    }

    func addVotedTracks(_ tracks: [ReferendumInfoView.Track]) {
        let sectionLabel = addSectionLabel()
        contentView.stackView.setCustomSpacing(Constants.actionOffset, after: sectionLabel)
        votedTracksTitleLabel = sectionLabel

        let linkButton = addLinkButton()
        contentView.stackView.setCustomSpacing(Constants.sectionInset, after: linkButton)
        removeVotesButton = linkButton

        addTrackViews(for: tracks)
    }

    func addDelegatedTracks(_ tracks: [ReferendumInfoView.Track]) {
        let sectionLabel = addSectionLabel()
        contentView.stackView.setCustomSpacing(Constants.sectionInset, after: sectionLabel)
        delegatedTracksTitleLabel = sectionLabel

        addTrackViews(for: tracks)
    }

    private func addSectionLabel() -> UILabel {
        let sectionLabel = UILabel()
        sectionLabel.apply(style: .footnoteSecondary)
        sectionLabel.numberOfLines = 0

        contentView.stackView.addArrangedSubview(sectionLabel)
        sectionLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        return sectionLabel
    }

    private func addLinkButton() -> RoundedButton {
        let button = RoundedButton()
        button.applyLinkStyle()

        contentView.stackView.addArrangedSubview(button)
        button.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        return button
    }

    private func addTrackViews(for viewModels: [ReferendumInfoView.Track]) {
        for viewModel in viewModels {
            let trackView = addTrackView(for: viewModel)
            contentView.stackView.setCustomSpacing(Constants.trackSpacing, after: trackView)
        }

        if let lastTrackView = trackViews.last {
            contentView.stackView.setCustomSpacing(Constants.sectionInset, after: lastTrackView)
        }
    }

    private func addTrackView(for viewModel: ReferendumInfoView.Track) -> BorderedIconLabelView {
        let trackView = BorderedIconLabelView()
        trackView.iconDetailsView.spacing = 6
        trackView.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        trackView.iconDetailsView.detailsLabel.numberOfLines = 1
        trackView.apply(style: .track)

        contentView.stackView.addArrangedSubview(trackView)
        trackView.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        trackViews.append(trackView)

        trackView.iconDetailsView.detailsLabel.text = viewModel.title

        let iconSize = trackView.iconDetailsView.iconWidth
        let imageSettings = ImageViewModelSettings(
            targetSize: CGSize(width: iconSize, height: iconSize),
            cornerRadius: nil,
            tintColor: BorderedIconLabelView.Style.track.text.textColor
        )

        viewModel.icon?.loadImage(
            on: trackView.iconDetailsView.imageView,
            settings: imageSettings,
            animated: true
        )

        return trackView
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(titleLabel)
        contentView.stackView.setCustomSpacing(Constants.tracksOffset, after: titleLabel)
    }
}

extension GovernanceUnavailableTracksViewLayout {
    static func estimatePreferredHeight(
        for votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    ) -> CGFloat {
        let titleHeight: CGFloat = 22

        var height = Constants.contentInsets.top + titleHeight + Constants.tracksOffset

        let trackHeight: CGFloat = 22

        if !delegatedTracks.isEmpty {
            height += titleHeight
            height += 2 * Constants.sectionInset + CGFloat(delegatedTracks.count - 1) *
                (trackHeight + Constants.trackSpacing) + trackHeight
        }

        if !votedTracks.isEmpty {
            height += 2 * titleHeight + Constants.actionOffset
            height += 2 * Constants.sectionInset + CGFloat(votedTracks.count - 1) *
                (trackHeight + Constants.trackSpacing) + trackHeight
        }

        return height
    }
}
