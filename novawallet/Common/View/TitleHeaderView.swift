import UIKit

final class TitleHeaderView: UICollectionReusableView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
    }

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            titleLabel.snp.updateConstraints {
                $0.edges.equalToSuperview().inset(contentInsets)
            }
        }
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
        addSubview(titleLabel)

        titleLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    func bind(title: String) {
        titleLabel.text = title
    }
}
