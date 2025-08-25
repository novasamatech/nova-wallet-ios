import Foundation
import SubstrateSdk

private struct StateKey: Hashable {
    let chainId: ChainModel.Id
    let accountId: AccountId
}

enum AssetConversionFeeSharedStateStore {
    private static var states: [StateKey: WeakWrapper] = [:]
    private static var feeServices: [StateKey: WeakWrapper] = [:]
    private static let mutex = NSLock()

    static func getOrCreateHydra(for host: ExtrinsicFeeEstimatorHostProtocol) -> HydraFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let state = StateKey(chainId: host.chain.chainId, accountId: host.account.accountId)

        if let flowState = states[state]?.target as? HydraFlowState {
            return flowState
        }

        let flowState = HydraFlowState(
            account: host.account,
            chain: host.chain,
            connection: host.connection,
            runtimeProvider: host.runtimeProvider,
            userStorageFacade: host.userStorageFacade,
            substrateStorageFacade: host.substrateStorageFacade,
            operationQueue: host.operationQueue,
            logger: host.logger
        )

        states[state] = WeakWrapper(target: flowState)

        return flowState
    }

    static func getOrCreateHydraFeeCurrencyService(
        for host: ExtrinsicFeeEstimatorHostProtocol,
        payerAccountId: AccountId
    ) -> HydraSwapFeeCurrencyService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let state = StateKey(chainId: host.chain.chainId, accountId: payerAccountId)

        if let service = feeServices[state]?.target as? HydraSwapFeeCurrencyService {
            return service
        }

        let service = HydraSwapFeeCurrencyService(
            payerAccountId: payerAccountId,
            connection: host.connection,
            runtimeProvider: host.runtimeProvider,
            operationQueue: host.operationQueue
        )

        feeServices[state] = WeakWrapper(target: service)

        service.setup()

        return service
    }
}
