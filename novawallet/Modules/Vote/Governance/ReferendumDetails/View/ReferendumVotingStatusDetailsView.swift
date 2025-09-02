import UIKit
import UIKit_iOS

final class ReferendumVotingStatusDetailsView: RoundedView {
    let statusView = ReferendumVotingStatusView()
    let votingProgressView = VotingProgressView()
    let ayeVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorIconPositive()!,
            accessoryImage: R.image.iconInfoFilled()!
        ))
    }

    let nayVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorIconNegative()!,
            accessoryImage: R.image.iconInfoFilled()!
        ))
    }

    let abstainVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorIconSecondary()!,
            accessoryImage: R.image.iconInfoFilled()!
        ))
    }

    let voteButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        apply(style: .cellWithoutHighlighting)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let votesContainerView = UIView.vStack(
            [
                ayeVotesView,
                nayVotesView,
                abstainVotesView
            ]
        )

        let content = UIView.vStack(
            [
                statusView,
                votingProgressView,
                votesContainerView,
                voteButton
            ]
        )

        content.setCustomSpacing(16.0, after: votingProgressView)
        content.setCustomSpacing(16.0, after: votesContainerView)

        content.alignment = .center

        addSubview(content)
        content.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(16)
            $0.leading.trailing.equalToSuperview()
        }

        voteButton.snp.makeConstraints { make in
            make.height.equalTo(44.0)
        }

        votesContainerView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        content.arrangedSubviews
            .filter { $0 !== votesContainerView }
            .forEach {
                $0.snp.makeConstraints { make in
                    make.width.equalTo(self).offset(-32)
                }
            }
    }
}

extension ReferendumVotingStatusDetailsView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let yOffset = statusView.bounds.height + 13

        let progressViewSkeletons = votingProgressView.createSkeletons(
            on: self,
            contentInsets: .init(
                top: yOffset,
                left: UIConstants.horizontalInset,
                bottom: 0,
                right: UIConstants.horizontalInset
            ),
            showsThreshold: false,
            spaceSize: spaceSize
        )

        return progressViewSkeletons
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [votingProgressView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

extension ReferendumVotingStatusDetailsView: BindableView {
    struct Model {
        let status: ReferendumVotingStatusView.Model
        let votingProgress: LoadableViewModelState<VotingProgressView.Model?>
        let aye: VoteRowView.Model?
        let nay: VoteRowView.Model?
        let abstain: VoteRowView.Model?
        let buttonText: String?
    }

    func bind(viewModel: Model) {
        statusView.bind(viewModel: viewModel.status)
        ayeVotesView.bindOrHide(viewModel: viewModel.aye)
        nayVotesView.bindOrHide(viewModel: viewModel.nay)
        abstainVotesView.bindOrHide(viewModel: viewModel.abstain)

        switch viewModel.votingProgress {
        case let .cached(value), let .loaded(value):
            isLoading = false
            stopLoadingIfNeeded()
            votingProgressView.bindOrHide(viewModel: value)
        case .loading:
            isLoading = true
            startLoadingIfNeeded()
        }

        if let buttonText = viewModel.buttonText {
            voteButton.isHidden = false
            voteButton.imageWithTitleView?.title = buttonText
            voteButton.invalidateLayout()
        } else {
            voteButton.isHidden = true
        }
    }
}
