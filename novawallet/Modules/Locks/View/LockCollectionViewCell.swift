import UIKit

final class LockCollectionViewCell: UICollectionViewCell {
    lazy var view = GenericTitleValueView<UILabel, MultiValueView>(
        titleView: titleLabel,
        valueView: valueLabel
    )
    private let titleLabel: UILabel = .create {
        $0.font = .regularFootnote
        $0.textColor = R.color.colorTextSecondary()
    }

    private let valueLabel: MultiValueView = .create {
        $0.apply(style: .rowContrasted)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 0))
        }
    }
}

extension LockCollectionViewCell {
    struct Model {
        let title: String
        let amount: String
        let price: String?
    }

    func bind(viewModel: Model) {
        view.titleView.text = viewModel.title
        view.valueView.bind(topValue: viewModel.amount, bottomValue: viewModel.price)
    }
}
