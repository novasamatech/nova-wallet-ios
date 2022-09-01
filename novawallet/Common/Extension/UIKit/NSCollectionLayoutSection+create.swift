import UIKit

extension NSCollectionLayoutSection {
    struct Settings {
        let estimatedRowHeight: CGFloat
        let estimatedHeaderHeight: CGFloat
        let sectionContentInsets: NSDirectionalEdgeInsets
        let sectionInterGroupSpacing: CGFloat
        let header: Header?

        struct Header {
            let pinToVisibleBounds: Bool
        }
    }

    static func createSectionLayoutWithFullWidthRow(settings: Settings) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(settings.estimatedRowHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(settings.estimatedHeaderHeight)
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = settings.sectionContentInsets
        section.interGroupSpacing = settings.sectionInterGroupSpacing

        guard let headerSettings = settings.header else {
            return section
        }

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
