import UIKit

extension NSCollectionLayoutSection {
    struct SectionHeader {
        let pinToVisibleBounds: Bool
        let height: NSCollectionLayoutDimension
    }

    struct VerticalSectionSettings {
        let estimatedRowHeight: CGFloat
        let sectionContentInsets: NSDirectionalEdgeInsets
        let sectionInterGroupSpacing: CGFloat
        let header: SectionHeader?
    }

    static func createSectionLayoutWithFullWidthRow(
        settings: VerticalSectionSettings
    ) -> NSCollectionLayoutSection {
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

        let section = NSCollectionLayoutSection(group: group)
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
