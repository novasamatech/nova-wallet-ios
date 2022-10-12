import UIKit

final class ReferendumVotingStatusDetailsView: UIView {
    let statusView = ReferendumVotingStatusView()
    let votingProgressView = VotingProgressView()
    
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
                votingProgressView
            ]
        )
        
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension ReferendumVotingStatusDetailsView {
    struct Model {
        let status: ReferendumVotingStatusView.Model
        let votingProgress: VotingProgressView.Model
    }
    
    func bind(viewModel: Model) {
        statusView.bind(viewModel: viewModel.status)
        votingProgressView.bind(viewModel: viewModel.votingProgress)
    }
}
