import UIKit
import SoraUI

final class ReferendumView: UIView {
    let referendumInfoView = ReferendumInfoView()
    let progressView = VotingProgressView()
    let yourVoteView = YourVotesView()
    var skeletonView: SkrullableView?

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
            progressView,
            yourVoteView
        ]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let referendumInfoViewSkeletonRects = referendumInfoView.skeletonSizes(contentInsets: .zero)
        return referendumInfoViewSkeletonRects.map {
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

extension ReferendumInfoView {
    func skeletonSizes(contentInsets: UIEdgeInsets) -> [CGRect] {
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

        return [
            .init(origin: statusSkeletonOffset, size: statusSkeletonSize)
        ]
    }
}
