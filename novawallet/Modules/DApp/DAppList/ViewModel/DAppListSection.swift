import Foundation

enum DAppListItem: Hashable {
    case header(WalletSwitchViewModel)
    case categorySelect([DAppCategoryViewModel])
    case favorites(DAppViewModel)
    case category(DAppViewModel)
}

struct DAppListSection: Hashable, SectionProtocol {
    let title: String?
    var cells: [DAppListItem]
}
