import UIKit
import SoraUI

final class ReferendumVotingStatusDetailsView: RoundedView {
    let statusView = ReferendumVotingStatusView()
    let votingProgressView = VotingProgressView()
    let ayeVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorIconPositive()!,
            accessoryImage: (R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!))!
        ))
    }

    let nayVotesView: VoteRowView = .create {
        $0.apply(style: .init(
            color: R.color.colorIconNegative()!,
            accessoryImage: (R.image.iconInfoFilled()?.tinted(with: R.color.colorIconSecondary()!))!
        ))
    }

    let voteButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
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
                nayVotesView
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

extension ReferendumVotingStatusDetailsView: BindableView {
    struct Model {
        let status: ReferendumVotingStatusView.Model
        let votingProgress: VotingProgressView.Model?
        let aye: VoteRowView.Model?
        let nay: VoteRowView.Model?
        let buttonText: String?
    }

    func bind(viewModel: Model) {
        statusView.bind(viewModel: viewModel.status)
        votingProgressView.bindOrHide(viewModel: viewModel.votingProgress)
        ayeVotesView.bindOrHide(viewModel: viewModel.aye)
        nayVotesView.bindOrHide(viewModel: viewModel.nay)
        if let buttonText = viewModel.buttonText {
            voteButton.isHidden = false
            voteButton.imageWithTitleView?.title = buttonText
            voteButton.invalidateLayout()
        } else {
            voteButton.isHidden = true
        }
    }
}
