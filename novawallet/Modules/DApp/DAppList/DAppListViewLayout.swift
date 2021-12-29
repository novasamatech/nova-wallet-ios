import UIKit

final class DAppListViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let collectionView: UICollectionView = {
        let flowLayout = DAppListFlowLayout()
        flowLayout.scrollDirection = .vertical

        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        return view
    }()

    var collectionViewLayout: UICollectionViewFlowLayout? {
        collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func findHeaderView() -> DAppListHeaderView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? DAppListHeaderView
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
    }
}
