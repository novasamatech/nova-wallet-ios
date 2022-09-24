import Foundation

protocol ChainRegistryFacadeProtocol {
    static var sharedRegistry: ChainRegistryProtocol { get }
}

final class ChainRegistryFacade: ChainRegistryFacadeProtocol {
    static let sharedRegistry: ChainRegistryProtocol = ChainRegistryFactory.createDefaultRegistry()
}
