import UIKit

extension NSCollectionLayoutSection {
    struct HorizontalSectionSettings {
        let estimatedRowWidth: CGFloat
        let rowHeight: CGFloat
        let sectionContentInsets: NSDirectionalEdgeInsets
        let sectionInterGroupSpacing: CGFloat
        let header: SectionHeader?
    }

    static func createOrthogonalHorizontalSection(
        settings: HorizontalSectionSettings
    ) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(settings.estimatedRowWidth),
            heightDimension: .absolute(settings.rowHeight)
        )

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 1)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.contentInsets = settings.sectionContentInsets
        section.interGroupSpacing = settings.sectionInterGroupSpacing

        guard let headerSettings = settings.header else {
            return section
        }

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: headerSettings.height
        )

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        sectionHeader.pinToVisibleBounds = headerSettings.pinToVisibleBounds

        section.boundarySupplementaryItems = [sectionHeader]

        return section
    }
}
