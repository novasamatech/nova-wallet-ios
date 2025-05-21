import UIKit

extension UICollectionViewDiffableDataSource where SectionIdentifierType: SectionProtocol {
    func apply(_ viewModel: [SectionIdentifierType]) where SectionIdentifierType.CellModel == ItemIdentifierType {
        var snapshot = NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>()
        snapshot.appendSections(viewModel)
        viewModel.forEach { section in
            snapshot.appendItems(section.cells, toSection: section)
        }

        apply(snapshot)
    }
}
