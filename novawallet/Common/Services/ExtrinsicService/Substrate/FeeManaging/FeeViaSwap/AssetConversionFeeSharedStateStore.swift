import Foundation
import SubstrateSdk

private struct StateKey: Hashable {
    let chainId: ChainModel.Id
    let accountId: AccountId
}

enum AssetConversionFeeSharedStateStore {
    private static var feeServices: [StateKey: WeakWrapper] = [:]
    private static var feeOracleStates: [ChainModel.Id: WeakWrapper] = [:]
    private static let mutex = NSLock()

    static func getOrCreateHydraFeeOracleState(
        for chainId: ChainModel.Id
    ) -> HydraFeeOracleState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = feeOracleStates[chainId]?.target as? HydraFeeOracleState {
            return state
        }

        let state = HydraFeeOracleState()

        feeOracleStates[chainId] = WeakWrapper(target: state)

        return state
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
