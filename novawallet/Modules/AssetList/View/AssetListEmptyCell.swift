import UIKit

final class AssetListEmptyCell: UICollectionViewCell {
    let view = EmptyCellContentView()

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
            $0.edges.equalToSuperview()
        }
    }

    func bind(text: String) {
        view.bind(text: text)
    }
}
