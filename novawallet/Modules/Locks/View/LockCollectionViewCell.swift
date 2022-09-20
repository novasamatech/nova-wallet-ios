import UIKit

final class LockCollectionViewCell: UICollectionViewCell {
    lazy var view = GenericTitleValueView<UILabel, MultiValueView>(
        titleView: titleLabel,
        valueView: valueLabel
    )
    private let titleLabel: UILabel = .create {
        $0.font = .regularFootnote
        $0.textColor = R.color.colorWhite64()
    }

    private let valueLabel: MultiValueView = .create {
        $0.valueTop.font = .regularFootnote
        $0.valueBottom.font = .caption1
        $0.valueTop.textColor = R.color.colorWhite64()
        $0.valueBottom.textColor = R.color.colorWhite64()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
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
