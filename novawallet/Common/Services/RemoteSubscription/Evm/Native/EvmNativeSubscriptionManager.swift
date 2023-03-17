import Foundation
import SubstrateSdk

final class EvmNativeSubscriptionManager {
    let chainId: ChainModel.Id
    let params: EvmNativeBalanceSubscriptionRequest
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?
    let serviceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let eventCenter: EventCenterProtocol

    private var syncService: SyncServiceProtocol?

    init(
        chainId: ChainModel.Id,
        params: EvmNativeBalanceSubscriptionRequest,
        serviceFactory: EvmBalanceUpdateServiceFactoryProtocol,
        connection: JSONRPCEngine,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol?
    ) {
        self.chainId = chainId
        self.params = params
        self.serviceFactory = serviceFactory
        self.connection = connection
        self.eventCenter = eventCenter
        self.logger = logger
    }

    private func performSubscription() {}

    private func subscribe() throws {
        syncService = try serviceFactory.createNativeBalanceUpdateService(
            for: params.holder,
            chainAssetId: .init(chainId: chainId, assetId: params.assetId),
            blockNumber: .latest
        ) { [weak self] _ in
            self?.syncService = nil
            self?.performSubscription()
        }

        syncService?.setup()
    }
}

extension EvmNativeSubscriptionManager: EvmRemoteSubscriptionProtocol {
    func start() throws {
        try subscribe()
    }
}
