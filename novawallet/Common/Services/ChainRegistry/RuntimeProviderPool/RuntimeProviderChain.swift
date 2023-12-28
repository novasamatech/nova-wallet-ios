import Foundation

struct RuntimeProviderChain: Equatable {
    let chainId: ChainModel.Id
    let typesUsage: ChainModel.TypesUsage
    let name: String
    let isEthereumBased: Bool
}
