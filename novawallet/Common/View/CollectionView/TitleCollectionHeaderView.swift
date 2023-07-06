import UIKit

final class TitleCollectionHeaderView: UICollectionReusableView {
    private let displayContentView = UIView()

    let titleLabel: UILabel = .create { label in
        label.apply(style: .title3Primary)
    }

    var contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            displayContentView.snp.updateConstraints { make in
                make.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    func bind(title: String) {
        titleLabel.text = title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(displayContentView)
        displayContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }

        displayContentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.trailing.equalToSuperview()
        }
    }
}
