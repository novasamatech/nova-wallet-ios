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
    var executionTimeEstimator: AssetExchangeTimeEstimating { get }
    var fungibilityPreservationProvider: AssetFungibilityPreservationProviding { get }
    var logger: LoggerProtocol { get }
}

final class CrosschainExchangeHost: CrosschainExchangeHostProtocol {
    let wallet: MetaAccountModel
    let allChains: IndexedChainModels
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let xcmService: XcmTransferServiceProtocol
    let resolutionFactory: XcmTransferResolutionFactoryProtocol
    let xcmTransfers: XcmTransfers
    let executionTimeEstimator: AssetExchangeTimeEstimating
    let fungibilityPreservationProvider: AssetFungibilityPreservationProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        wallet: MetaAccountModel,
        allChains: IndexedChainModels,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        xcmService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        xcmTransfers: XcmTransfers,
        executionTimeEstimator: AssetExchangeTimeEstimating,
        fungibilityPreservationProvider: AssetFungibilityPreservationProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.allChains = allChains
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.xcmService = xcmService
        self.resolutionFactory = resolutionFactory
        self.xcmTransfers = xcmTransfers
        self.executionTimeEstimator = executionTimeEstimator
        self.fungibilityPreservationProvider = fungibilityPreservationProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}
