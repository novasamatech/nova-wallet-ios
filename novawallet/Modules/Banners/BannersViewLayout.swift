import UIKit

final class BannersViewLayout: UIView {
    let containerView: UIView = .create { view in
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let backgroundImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
    }

    lazy var collectionView: UICollectionView = {
        let layout = createCompositionalLayout()
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false

        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        collectionView.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersViewLayout {
    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func createCompositionalLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(126)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
            self?.updateCellAppearance(items: items, offset: offset, environment: environment)
        }

        return UICollectionViewCompositionalLayout(section: section)
    }

    func updateCellAppearance(
        items: [NSCollectionLayoutVisibleItem],
        offset: CGPoint,
        environment: NSCollectionLayoutEnvironment
    ) {
        let containerWidth = environment.container.contentSize.width
        items.forEach { item in
            let distanceFromCenter = abs((item.frame.midX - offset.x) - containerWidth / 2)
            let maxDistance = containerWidth / 2
            let opacity = 1 - (distanceFromCenter / maxDistance)
            item.alpha = opacity
        }
    }
}

// MARK: Internal

extension BannersViewLayout {
    func setBackgroundImage(_ image: UIImage?) {
        backgroundImageView.image = image
    }
}
