import UIKit

final class TransactionHistoryHeaderView: UIView {
    private let titleLabel = UILabel(style: .semiboldCaps2Secondary)

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
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
    }

    func bind(title: String) {
        titleLabel.text = title.uppercased()
    }
}
