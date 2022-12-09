import Foundation

struct TokenManageNetworkViewModel: Hashable {
    let network: NetworkViewModel
    let chainAssetId: ChainAssetId
    let isOn: Bool

    static func == (lhs: TokenManageNetworkViewModel, rhs: TokenManageNetworkViewModel) -> Bool {
        lhs.chainAssetId == rhs.chainAssetId && lhs.network.name == rhs.network.name && lhs.isOn == rhs.isOn
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(chainAssetId)
        hasher.combine(network.name)
        hasher.combine(isOn)
    }
}
