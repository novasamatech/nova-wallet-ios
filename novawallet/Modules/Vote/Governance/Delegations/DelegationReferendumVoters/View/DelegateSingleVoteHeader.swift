import UIKit

final class DelegateSingleVoteHeader: UICollectionReusableView {
    var delegateInfoView = DelegateInfoView()

    var votesView: MultiValueView = .create {
        $0.stackView.alignment = .fill
        $0.valueTop.apply(style: .footnotePrimary)
        $0.valueBottom.apply(style: .caption1Secondary)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        $0.valueBottom.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(delegateInfoView)
        delegateInfoView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(votesView)
        votesView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(delegateInfoView.snp.trailing).offset(8)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DelegateSingleVoteHeader {
    struct Model: Equatable {
        let delegateInfo: DelegateInfoView.Model
        let votes: MultiValueView.Model

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.delegateInfo == rhs.delegateInfo && lhs.votes == rhs.votes
        }
    }

    func bind(viewModel: Model) {
        delegateInfoView.bind(viewModel: viewModel.delegateInfo)
        votesView.bind(viewModel: viewModel.votes)
    }
}
