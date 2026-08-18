import Foundation
import SubstrateSdk

private struct StateKey: Hashable {
    let chainId: ChainModel.Id
    let accountId: AccountId
}

enum AssetConversionFeeSharedStateStore {
    private static var feeServices: [StateKey: WeakWrapper] = [:]
    private static let mutex = NSLock()

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
