import UIKit

final class DelegateSingleVoteCollectionViewCell: UICollectionViewCell {
    typealias ContentView = GenericTitleValueView<DelegateInfoView, MultiValueView>
    let baseView = ContentView()

    var topLineView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
    }

    var middleLineView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
    }

    var bottomLineView: UIView = .create {
        $0.backgroundColor = R.color.colorBlockBackground()
    }

    var delegateInfoView: DelegateInfoView {
        baseView.titleView
    }

    var votesView: MultiValueView {
        baseView.valueView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(baseView)
        addSubview(topLineView)
        addSubview(middleLineView)
        addSubview(bottomLineView)

        baseView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.top.bottom.equalToSuperview()
            $0.leading.equalTo(middleLineView.snp.trailing).offset(12)
        }

        middleLineView.snp.makeConstraints {
            $0.height.equalTo(2)
            $0.width.equalTo(11)
            $0.leading.equalTo(topLineView.snp.trailing)
            $0.centerY.equalToSuperview()
        }

        topLineView.snp.makeConstraints {
            $0.width.equalTo(2)
            $0.top.equalToSuperview()
            $0.bottom.equalTo(middleLineView.snp.bottom)
            $0.leading.equalToSuperview().inset(27)
        }

        bottomLineView.snp.makeConstraints {
            $0.width.equalTo(2)
            $0.top.equalTo(middleLineView.snp.bottom)
            $0.bottom.equalToSuperview()
            $0.trailing.equalTo(middleLineView.snp.leading)
        }

        votesView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func applyStyle() {
        backgroundColor = R.color.colorBlockBackground()

        votesView.stackView.alignment = .fill
        votesView.valueTop.apply(style: .footnotePrimary)
        votesView.valueBottom.apply(style: .caption1Secondary)
        delegateInfoView.isUserInteractionEnabled = false
    }
}

extension DelegateSingleVoteCollectionViewCell {
    struct Model: Hashable {
        static func == (
            lhs: DelegateSingleVoteCollectionViewCell.Model,
            rhs: DelegateSingleVoteCollectionViewCell.Model
        ) -> Bool {
            lhs.delegateInfo.addressViewModel.address == rhs.delegateInfo.addressViewModel.address
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(delegateInfo.addressViewModel.address)
        }

        let delegateInfo: DelegateInfoView.Model
        let votes: MultiValueView.Model
    }

    func bind(viewModel: Model) {
        delegateInfoView.bind(viewModel: viewModel.delegateInfo)
        votesView.bind(viewModel: viewModel.votes)
    }
}

extension DelegateSingleVoteCollectionViewCell {
    enum Position {
        case top
        case middle
        case bottom
    }

    func apply(position: Position) {
        switch position {
        case .top, .middle:
            bottomLineView.isHidden = false
        case .bottom:
            bottomLineView.isHidden = true
        }
    }
}
