import UIKit

final class ReferendumView: UIView {
    let referendumInfoView = ReferendumInfoView()
    let progressView = VotingProgressView()
    let yourVoteView = YourVotesView()

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
        // TODO: Skeleton
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
