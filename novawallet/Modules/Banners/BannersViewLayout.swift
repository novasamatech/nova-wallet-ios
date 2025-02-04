import UIKit

final class BannersViewLayout: UIView {
    let collectionView: UICollectionView = .create { view in
        view.isPagingEnabled = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersViewLayout {
    func createCompositionalLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(343)
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
