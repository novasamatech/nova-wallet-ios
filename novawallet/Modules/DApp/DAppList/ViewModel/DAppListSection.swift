import Foundation

enum DAppListSection: Hashable, SectionProtocol {
    var cells: [DAppListItem] {
        switch self {
        case let .header(model),
             let .categorySelect(model),
             let .favorites(model),
             let .category(model):
            model.items
        }
    }

    typealias CellModel = DAppListItem

    case header(DAppListSectionViewModel)
    case categorySelect(DAppListSectionViewModel)
    case favorites(DAppListSectionViewModel)
    case category(DAppListSectionViewModel)
}

enum DAppListItem: Hashable {
    case header(WalletSwitchViewModel)
    case categorySelect([DAppCategoryViewModel])
    case favorites(DAppViewModel)
    case category(DAppViewModel)
}

struct DAppListSectionViewModel: Hashable {
    let title: String?
    let items: [DAppListItem]
}
