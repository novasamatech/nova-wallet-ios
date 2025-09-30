import Foundation

struct AHMInfoExcludedChains: Codable {
    var chainIds: Set<ChainModel.Id>

    mutating func add(_ chainId: ChainModel.Id) {
        chainIds.insert(chainId)
    }
}
