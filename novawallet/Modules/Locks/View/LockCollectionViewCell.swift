import UIKit

final class LockCollectionViewCell: UICollectionViewCell {
    lazy var view = GenericTitleValueView<UILabel, UILabel>(
        titleView: titleLabel,
        valueView: valueLabel
    )
    private let titleLabel: UILabel = .create {
        $0.font = .regularSubheadline
        $0.textColor = R.color.colorWhite48()
    }

    private let valueLabel: UILabel = .create {
        $0.font = .regularSubheadline
        $0.textColor = R.color.colorWhite48()
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

    func bind(title: String, value: String) {
        view.titleView.text = title
        view.valueView.text = value
    }
}
