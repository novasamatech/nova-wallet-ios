import Foundation

struct AHMInfoShownChains: Codable {
    var chainIds: Set<ChainModel.Id>

    mutating func add(_ chainId: ChainModel.Id) {
        chainIds.insert(chainId)
    }
}
