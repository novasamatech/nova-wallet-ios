import Foundation

struct ManageTokenSection {
    let title: String
    let icon: ImageViewModelProtocol?
    let items: [ManageTokenItem]
    let isExpanded: Bool
    let enabledCount: Int

    var allEnabled: Bool {
        enabledCount == items.count
    }
}

struct ManageTokenItem: Hashable {
    let chainAssetId: ChainAssetId
    let name: String
    let icon: ImageViewModelProtocol?
    let isEnabled: Bool

    static func == (lhs: ManageTokenItem, rhs: ManageTokenItem) -> Bool {
        lhs.chainAssetId == rhs.chainAssetId && lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(chainAssetId)
        hasher.combine(isEnabled)
    }
}
