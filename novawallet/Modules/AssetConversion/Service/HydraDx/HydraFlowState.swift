import Foundation
import SubstrateSdk

final class HydraFlowState {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let userStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    let mutex = NSLock()

    private var omnipoolFlowState: HydraOmnipoolFlowState?
    private var stableswapFlowState: HydraStableswapFlowState?

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.operationQueue = operationQueue
    }
}

extension HydraFlowState {
    func getOmnipoolFlowState() -> HydraOmnipoolFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = omnipoolFlowState {
            return state
        }

        let newState = HydraOmnipoolFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            operationQueue: operationQueue
        )

        omnipoolFlowState = newState

        return newState
    }

    func getStableswapFlowState() -> HydraStableswapFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let state = stableswapFlowState {
            return state
        }

        let newState = HydraStableswapFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            operationQueue: operationQueue
        )

        stableswapFlowState = newState

        return newState
    }
}
