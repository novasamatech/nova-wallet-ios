import UIKit
import UIKit_iOS

final class ReferendumView: UIView {
    let referendumInfoView = ReferendumInfoView()
    let progressView = VotingProgressView()
    let yourVoteView = HideSecureView<YourVotesView>()
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView == nil, viewModel?.isLoading == true {
            updateLoadingState()
        }
    }
}

typealias ReferendumTableViewCell = BlurredTableViewCell<ReferendumView>

extension ReferendumTableViewCell {
    func applyStyle() {
        shouldApplyHighlighting = true
        contentInsets = .init(top: 4, left: 16, bottom: 4, right: 16)
        innerInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
    }
}

extension ReferendumView {
    struct Model {
        var referendumInfo: ReferendumInfoView.Model
        let progress: VotingProgressView.Model?
        let yourVotes: YourVotesView.Model?
    }

    func bind(securedCellmodel: SecuredViewModel<ReferendumsCellViewModel>) {
        viewModel = securedCellmodel.originalContent.viewModel

        guard let model = securedCellmodel.originalContent.viewModel.value else {
            return
        }
        referendumInfoView.bind(viewModel: model.referendumInfo)

        if let progressModel = model.progress {
            progressView.bind(viewModel: progressModel)
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }

        yourVoteView.bind(securedCellmodel.privacyMode)

        if let yourVotesModel = model.yourVotes {
            yourVoteView.originalView.bind(viewModel: yourVotesModel)
            yourVoteView.isHidden = false
        } else {
            yourVoteView.isHidden = true
        }
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
            yourVoteView.originalView.bind(viewModel: yourVotesModel)
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
            progressView,
            yourVoteView
        ]
    }

    func updateLoadingState() {
        if viewModel?.isLoading == false {
            stopLoadingIfNeeded()
        } else {
            startLoadingIfNeeded()
        }
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let (referendumInfoViewSkeletons, referendumInfoViewBottomViewMaxY) =
            referendumInfoView.createSkeletons(on: self, contentInsets: .zero, spaceSize: spaceSize)

        let progressViewSkeletons = progressView.createSkeletons(
            on: self,
            contentInsets: .init(top: referendumInfoViewBottomViewMaxY, left: 0, bottom: 0, right: 0),
            spaceSize: spaceSize
        )

        return referendumInfoViewSkeletons + progressViewSkeletons
    }
}

extension VotingProgressView {
    // swiftlint:disable:next function_body_length
    func createSkeletons(
        on view: UIView,
        contentInsets externalInsets: UIEdgeInsets,
        showsThreshold: Bool = true,
        spaceSize: CGSize
    ) -> [SingleSkeleton] {
        let contentInsets = UIEdgeInsets(
            top: externalInsets.top + Constants.contentInsets.top,
            left: externalInsets.left + Constants.contentInsets.left,
            bottom: externalInsets.bottom + Constants.contentInsets.bottom,
            right: externalInsets.right + Constants.contentInsets.right
        )
        let tresholdSkeletonSize = showsThreshold ? CGSize(width: 121, height: 8) : .zero
        let progressSkeletonHeight: CGFloat = 5
        let votingSkeletonSize = CGSize(width: 60, height: 8)

        let thresholdViewHeight = showsThreshold
            ? max(thresholdView.iconWidth, thresholdView.detailsLabel.font.lineHeight)
            : .zero
        let thresholdSkeletonOffsetY = contentInsets.top + thresholdViewHeight / 2 - tresholdSkeletonSize.height / 2
        let thresholdSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: thresholdSkeletonOffsetY
        )

        let progressOffsetY = contentInsets.top + thresholdViewHeight + Constants.verticalSpace
        let sliderHeight = slider.intrinsicContentSize.height
        let progressSkeletonOffsetY = progressOffsetY + sliderHeight / 2 - progressSkeletonHeight / 2
        let progressHalfWidth = (spaceSize.width - contentInsets.left - contentInsets.right - 6) / 2

        let progressSkeletonFirstPartOffset = CGPoint(
            x: contentInsets.left,
            y: progressSkeletonOffsetY
        )
        let progressSkeletonSecondPartOffset = CGPoint(
            x: progressSkeletonFirstPartOffset.x + progressHalfWidth + 6,
            y: progressSkeletonOffsetY
        )
        let progressSkeletonSize = CGSize(width: progressHalfWidth, height: progressSkeletonHeight)
        let votingSkeletonOffsetY = progressOffsetY + sliderHeight + Constants.verticalSpace +
            ayeProgressLabel.font.lineHeight / 2 - votingSkeletonSize.height / 2
        let ayeVotingSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: votingSkeletonOffsetY
        )
        let nayVotingSkeletonOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - votingSkeletonSize.width,
            y: votingSkeletonOffsetY
        )
        let progressCenterX = (progressSkeletonSecondPartOffset.x + progressSkeletonSize.width -
            progressSkeletonFirstPartOffset.x) / 2
        let passVotingSkeletonOffset = CGPoint(
            x: progressCenterX - votingSkeletonSize.width / 2,
            y: votingSkeletonOffsetY
        )

        return [
            CGRect(origin: thresholdSkeletonOffset, size: tresholdSkeletonSize),
            CGRect(origin: progressSkeletonFirstPartOffset, size: progressSkeletonSize),
            CGRect(origin: progressSkeletonSecondPartOffset, size: progressSkeletonSize),
            CGRect(origin: ayeVotingSkeletonOffset, size: votingSkeletonSize),
            CGRect(origin: passVotingSkeletonOffset, size: votingSkeletonSize),
            CGRect(origin: nayVotingSkeletonOffset, size: votingSkeletonSize)
        ].map {
            SingleSkeleton.createRow(
                on: view,
                containerView: view,
                spaceSize: spaceSize,
                offset: $0.origin,
                size: $0.size
            )
        }
    }
}

extension ReferendumInfoView {
    // swiftlint:disable:next function_body_length
    func createSkeletons(on view: UIView, contentInsets: UIEdgeInsets, spaceSize: CGSize) -> (
        skeletons: [SingleSkeleton],
        bottomViewMaxY: CGFloat
    ) {
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

        let timeSkeletonOffsetY = contentInsets.top + timeView.detailsLabel.font.lineHeight / 2 -
            timeSkeletonSize.height / 2
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
        let trackNameSkeletonOffsetY = trackNameOffsetY + Constants.trackInformationHeight / 2 -
            trackNameSkeletonSize.height / 2

        let trackNameSkeletonOffset = CGPoint(
            x: contentInsets.left,
            y: trackNameSkeletonOffsetY
        )

        let numberSkeletonOffset = CGPoint(
            x: trackNameSkeletonOffset.x + trackNameSkeletonSize.width + Constants.trackInformationHorizontalSpace,
            y: trackNameSkeletonOffsetY
        )

        return (
            skeletons: [
                SingleSkeleton.createRow(
                    on: view,
                    containerView: view,
                    spaceSize: spaceSize,
                    offset: statusSkeletonOffset,
                    size: statusSkeletonSize
                ),
                SingleSkeleton.createRow(
                    on: view,
                    containerView: view,
                    spaceSize: spaceSize,
                    offset: timeSkeletonOffset,
                    size: timeSkeletonSize
                ),
                SingleSkeleton.createRow(
                    on: view,
                    containerView: view,
                    spaceSize: spaceSize,
                    offset: titleSkeletonOffset,
                    size: titleSkeletonSize
                ),
                SingleSkeleton.createRow(
                    on: view,
                    containerView: view,
                    spaceSize: spaceSize,
                    offset: trackNameSkeletonOffset,
                    size: trackNameSkeletonSize,
                    cornerRadii: .init(
                        width: 7 / trackNameSkeletonSize.width,
                        height: 7 / trackNameSkeletonSize.height
                    )
                ),
                SingleSkeleton.createRow(
                    on: view,
                    containerView: view,
                    spaceSize: spaceSize,
                    offset: numberSkeletonOffset,
                    size: numberSkeletonSize,
                    cornerRadii: .init(
                        width: 7 / numberSkeletonSize.width,
                        height: 7 / numberSkeletonSize.height
                    )
                )
            ],
            bottomViewMaxY: trackNameOffsetY + Constants.trackInformationHeight
        )
    }
}
