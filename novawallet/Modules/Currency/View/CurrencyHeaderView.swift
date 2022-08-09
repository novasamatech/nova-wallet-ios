import UIKit

final class CurrencyHeaderView: UICollectionReusableView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite64()
        label.font = .regularFootnote
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(title: String) {
        titleLabel.text = title
    }
}
