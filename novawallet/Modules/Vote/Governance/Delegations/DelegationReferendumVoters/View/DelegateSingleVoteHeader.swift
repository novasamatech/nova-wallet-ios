import UIKit

final class DelegateSingleVoteHeader: UICollectionReusableView {
    typealias ContentView = GenericTitleValueView<DelegateInfoView, MultiValueView>
    let baseView = ContentView()

    var delegateInfoView: DelegateInfoView {
        baseView.titleView
    }

    var votesView: MultiValueView {
        baseView.valueView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(baseView)
        baseView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyStyle() {
        backgroundColor = .clear

        votesView.stackView.alignment = .fill
        votesView.valueTop.apply(style: .footnotePrimary)
        votesView.valueBottom.apply(style: .caption1Secondary)
        votesView.setContentCompressionResistancePriority(.required, for: .horizontal)
        votesView.valueBottom.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

extension DelegateSingleVoteHeader {
    struct Model {
        let delegateInfo: DelegateInfoView.Model
        let votes: MultiValueView.Model
    }

    func bind(viewModel: Model) {
        delegateInfoView.bind(viewModel: viewModel.delegateInfo)
        votesView.bind(viewModel: viewModel.votes)
    }
}
