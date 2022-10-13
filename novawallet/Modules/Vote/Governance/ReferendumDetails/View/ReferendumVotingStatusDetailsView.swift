import UIKit

final class ReferendumVotingStatusDetailsView: UIView {
    let statusView = ReferendumVotingStatusView()
    let votingProgressView = VotingProgressView()
    let ayeVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorRedFF3A69()!,
            accessoryImage: R.image.iconInfo()!
        ))
    }

    let nayVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorDarkGreen()!,
            accessoryImage: R.image.iconInfo()!
        ))
    }

    let voteButton = ButtonLargeControl()

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
            spacing: 16,
            [
                statusView,
                votingProgressView,
                UIView.vStack(
                    distribution: .fillEqually,
                    [
                        ayeVotesView,
                        nayVotesView
                    ]
                ),
                voteButton
            ]
        )
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
        }
    }
}

extension ReferendumVotingStatusDetailsView {
    struct Model {
        let status: ReferendumVotingStatusView.Model
        let votingProgress: VotingProgressView.Model
        let aye: VoteRowView.Model?
        let nay: VoteRowView.Model?
        let buttonText: String
    }

    func bind(viewModel: Model) {
        statusView.bind(viewModel: viewModel.status)
        votingProgressView.bind(viewModel: viewModel.votingProgress)
        viewModel.aye.map {
            ayeVotesView.bind(viewModel: $0)
        }
        viewModel.nay.map {
            nayVotesView.bind(viewModel: $0)
        }
        voteButton.bind(title: viewModel.buttonText, details: nil)
    }
}
