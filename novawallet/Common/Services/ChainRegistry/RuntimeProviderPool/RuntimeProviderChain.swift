import Foundation

struct RuntimeProviderChain: RuntimeProviderChainProtocol {
    let chainId: ChainModel.Id
    let typesUsage: ChainModel.TypesUsage
    let name: String
    let isEthereumBased: Bool
}

protocol RuntimeProviderChainProtocol: Equatable {
    var chainId: ChainModel.Id { get }
    var typesUsage: ChainModel.TypesUsage { get }
    var name: String { get }
    var isEthereumBased: Bool { get }
}
