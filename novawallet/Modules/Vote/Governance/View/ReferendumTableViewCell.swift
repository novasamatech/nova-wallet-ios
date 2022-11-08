import UIKit
import SoraUI

final class ReferendumView: UIView {
    let referendumInfoView = ReferendumInfoView()
    let progressView = VotingProgressView()
    let yourVoteView = YourVotesView()
    var skeletonView: SkrullableView?
    private var viewModel: LoadableViewModelState<Model>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 0,
            [
                referendumInfoView,
                progressView,
                yourVoteView
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

typealias ReferendumTableViewCell = BlurredTableViewCell<ReferendumView>

extension ReferendumTableViewCell {
    func applyStyle() {
        shouldApplyHighlighting = true
        contentInsets = .init(top: 8, left: 16, bottom: 8, right: 16)
        innerInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
    }
}

extension ReferendumView {
    struct Model {
        let referendumInfo: ReferendumInfoView.Model
        let progress: VotingProgressView.Model?
        let yourVotes: YourVotesView.Model?
    }

    func bind(viewModel: LoadableViewModelState<Model>) {
        self.viewModel = viewModel

        guard let model = viewModel.value else {
            return
        }
        referendumInfoView.bind(viewModel: model.referendumInfo)
        if let progressModel = model.progress {
            progressView.bind(viewModel: progressModel)
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }

        if let yourVotesModel = model.yourVotes {
            yourVoteView.bind(viewModel: yourVotesModel)
            yourVoteView.isHidden = false
        } else {
            yourVoteView.isHidden = true
        }
    }
}

extension ReferendumView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [
            referendumInfoView,
            progressView
        ]
    }

    func updateLoadingState() {
        guard let viewModel = viewModel, viewModel.value != nil else {
            startLoadingIfNeeded()
            return
        }

        stopLoadingIfNeeded()
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let (referendumInfoViewSkeletonRects, offset) = referendumInfoView.skeletonSizes(contentInsets: .zero, spaceSize: spaceSize)

        let progressViewSkeletonRects = progressView.skeletonSizes(contentInsets: .init(
            top: offset,
            left: 0,
            bottom: 0,
            right: 0
        ), spaceSize: spaceSize)
        return (referendumInfoViewSkeletonRects + progressViewSkeletonRects).map {
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: $0.origin,
                size: $0.size
            )
        }
    }
}

extension VotingProgressView {
    func skeletonSizesBasedOnBottom(spaceSize: CGSize) -> [CGRect] {
        let contentInsets = Constants.contentInsets
        let tresholdSkeletonSize = CGSize(width: 121, height: 8)
        let progressSkeletonSize = CGSize(width: 152.5, height: 5)
        let votingSkeletonSize = CGSize(width: 60, height: 8)

        let votingOffsetY = spaceSize.height - contentInsets.bottom
        let votingSkeletonOffsetY = votingOffsetY - ayeProgressLabel.font.lineHeight / 2 - votingSkeletonSize.height / 2
        let ayeVotingSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: votingSkeletonOffsetY
        )
        let nayVotingSkeletonOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - votingSkeletonSize.width,
            y: votingSkeletonOffsetY
        )

        let passVotingSkeletonOffset = CGPoint(
            x: nayVotingSkeletonOffset.x - (ayeVotingSkeletonOffset.x + votingSkeletonSize.width) / 2,
            y: votingSkeletonOffsetY
        )

        let progressOffsetY = votingOffsetY - ayeProgressLabel.font.lineHeight - Constants.verticalSpace
        let progressSkeletonOffsetY = progressOffsetY - slider.intrinsicContentSize.height / 2 - progressSkeletonSize.height / 2

        let progressSkeletonFirstPartOffset = CGPoint(
            x: contentInsets.left,
            y: progressSkeletonOffsetY
        )
        let progressSkeletonSecondPartOffset = CGPoint(
            x: progressSkeletonFirstPartOffset.x + progressSkeletonSize.width + 6,
            y: progressSkeletonOffsetY
        )

        let thresholdSkeletonOffsetY = progressOffsetY - slider.intrinsicContentSize.height - tresholdSkeletonSize.height / 2
        let thresholdSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: thresholdSkeletonOffsetY
        )
        return [
            .init(origin: thresholdSkeletonOffset, size: tresholdSkeletonSize),
            .init(origin: progressSkeletonFirstPartOffset, size: progressSkeletonSize),
            .init(origin: progressSkeletonSecondPartOffset, size: progressSkeletonSize),
            .init(origin: ayeVotingSkeletonOffset, size: votingSkeletonSize),
            .init(origin: passVotingSkeletonOffset, size: votingSkeletonSize),
            .init(origin: nayVotingSkeletonOffset, size: votingSkeletonSize)
        ]
    }

    func skeletonSizes(contentInsets externalInsets: UIEdgeInsets, spaceSize: CGSize) -> [CGRect] {
        let contentInsets = UIEdgeInsets(
            top: externalInsets.top + Constants.contentInsets.top,
            left: externalInsets.left + Constants.contentInsets.left,
            bottom: externalInsets.bottom + Constants.contentInsets.bottom,
            right: externalInsets.right + Constants.contentInsets.right
        )
        let tresholdSkeletonSize = CGSize(width: 121, height: 8)
        let progressSkeletonSize = CGSize(width: 152.5, height: 5)
        let votingSkeletonSize = CGSize(width: 60, height: 8)

        let thresholdViewHeight = max(thresholdView.iconWidth, thresholdView.detailsLabel.font.lineHeight)
        let thresholdSkeletonOffsetY = contentInsets.top + thresholdViewHeight / 2 - tresholdSkeletonSize.height / 2
        let thresholdSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: thresholdSkeletonOffsetY
        )

        let progressOffsetY = contentInsets.top + thresholdViewHeight + Constants.verticalSpace
        let progressSkeletonOffsetY = progressOffsetY + slider.intrinsicContentSize.height / 2 - progressSkeletonSize.height / 2
        let progressSkeletonFirstPartOffset = CGPoint(
            x: contentInsets.left,
            y: progressSkeletonOffsetY
        )
        let progressSkeletonSecondPartOffset = CGPoint(
            x: progressSkeletonFirstPartOffset.x + progressSkeletonSize.width + 6,
            y: progressSkeletonOffsetY
        )

        let votingSkeletonOffsetY = progressOffsetY + slider.intrinsicContentSize.height + Constants.verticalSpace + ayeProgressLabel.font.lineHeight / 2 - votingSkeletonSize.height / 2
        let ayeVotingSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: votingSkeletonOffsetY
        )
        let nayVotingSkeletonOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - votingSkeletonSize.width,
            y: votingSkeletonOffsetY
        )
        let progressCenterX = (progressSkeletonSecondPartOffset.x + progressSkeletonSize.width - progressSkeletonFirstPartOffset.x) / 2
        let passVotingSkeletonOffset = CGPoint(
            x: progressCenterX - votingSkeletonSize.width / 2,
            y: votingSkeletonOffsetY
        )

        return [
            .init(origin: thresholdSkeletonOffset, size: tresholdSkeletonSize),
            .init(origin: progressSkeletonFirstPartOffset, size: progressSkeletonSize),
            .init(origin: progressSkeletonSecondPartOffset, size: progressSkeletonSize),
            .init(origin: ayeVotingSkeletonOffset, size: votingSkeletonSize),
            .init(origin: passVotingSkeletonOffset, size: votingSkeletonSize),
            .init(origin: nayVotingSkeletonOffset, size: votingSkeletonSize)
        ]
    }
}

extension ReferendumInfoView {
    func skeletonSizes(contentInsets: UIEdgeInsets, spaceSize: CGSize) -> ([CGRect], CGFloat) {
        let statusSkeletonSize = CGSize(width: 60, height: 12)
        let timeSkeletonSize = CGSize(width: 116, height: 12)
        let titleSkeletonSize = CGSize(width: 178, height: 12)
        let trackNameSkeletonSize = CGSize(width: 121, height: 22)
        let numberSkeletonSize = CGSize(width: 46, height: 22)

        let statusSkeletonOffsetY = contentInsets.top + statusLabel.font.lineHeight / 2 - statusSkeletonSize.height / 2

        let statusSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: statusSkeletonOffsetY
        )

        let timeSkeletonOffsetY = contentInsets.top + timeView.detailsLabel.font.lineHeight / 2 - timeSkeletonSize.height / 2
        let timeSkeletonOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - timeSkeletonSize.width,
            y: timeSkeletonOffsetY
        )

        let titleOffsetY = contentInsets.top + statusLabel.font.lineHeight + Constants.verticalSpace
        let titleSkeletonOffsetY: CGFloat = titleOffsetY + titleLabel.font.lineHeight / 2 - titleSkeletonSize.height / 2

        let titleSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: titleSkeletonOffsetY
        )
        let trackNameOffsetY = contentInsets.top + statusLabel.font.lineHeight + Constants.verticalSpace +
            titleLabel.font.lineHeight + Constants.afterTitleLabelVerticalSpace
        let trackNameSkeletonOffsetY = trackNameOffsetY + Constants.trackInformationHeght / 2 - trackNameSkeletonSize.height / 2

        let trackNameSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: trackNameSkeletonOffsetY
        )

        let numberSkeletonOffset = CGPoint(
            x: trackNameSkeletonOffset.x + trackNameSkeletonSize.width + Constants.trackInformationHorizontalSpace,
            y: trackNameSkeletonOffsetY
        )

        return ([
            .init(origin: statusSkeletonOffset, size: statusSkeletonSize),
            .init(origin: timeSkeletonOffset, size: timeSkeletonSize),
            .init(origin: titleSkeletonOffset, size: titleSkeletonSize),
            .init(origin: trackNameSkeletonOffset, size: trackNameSkeletonSize),
            .init(origin: numberSkeletonOffset, size: numberSkeletonSize)
        ], trackNameOffsetY + Constants.trackInformationHeght)
    }
}
