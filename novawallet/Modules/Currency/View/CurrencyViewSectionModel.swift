import Foundation

struct CurrencyViewSectionModel: Hashable, SectionProtocol {
    typealias CellModel = CurrencyCollectionViewCell.Model

    var title: String
    var cells: [CellModel]
}
