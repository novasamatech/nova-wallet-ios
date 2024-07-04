import Foundation

struct RuntimeProviderChain: Equatable, RuntimeProviderChainProtocol {
    let chainId: ChainModel.Id
    let typesUsage: ChainModel.TypesUsage
    let name: String
    let isEthereumBased: Bool
}

protocol RuntimeProviderChainProtocol {
    var chainId: ChainModel.Id { get }
    var typesUsage: ChainModel.TypesUsage { get }
    var name: String { get }
    var isEthereumBased: Bool { get }
}
