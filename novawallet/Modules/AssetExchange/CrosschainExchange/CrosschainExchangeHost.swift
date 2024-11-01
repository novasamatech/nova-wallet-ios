import Foundation

protocol CrosschainExchangeHostProtocol {
    var wallet: MetaAccountModel { get }
    var allChains: IndexedChainModels { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var signingWrapperFactory: SigningWrapperFactoryProtocol { get }
    var xcmService: XcmTransferServiceProtocol { get }
    var resolutionFactory: XcmTransferResolutionFactoryProtocol { get }
    var xcmTransfers: XcmTransfers { get }
    var operationQueue: OperationQueue { get }
}

final class CrosschainExchangeHost: CrosschainExchangeHostProtocol {
    let wallet: MetaAccountModel
    let allChains: IndexedChainModels
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let xcmService: XcmTransferServiceProtocol
    let resolutionFactory: XcmTransferResolutionFactoryProtocol
    let xcmTransfers: XcmTransfers
    let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        allChains: IndexedChainModels,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        xcmService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        xcmTransfers: XcmTransfers,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.allChains = allChains
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.xcmService = xcmService
        self.resolutionFactory = resolutionFactory
        self.xcmTransfers = xcmTransfers
        self.operationQueue = operationQueue
    }
}
