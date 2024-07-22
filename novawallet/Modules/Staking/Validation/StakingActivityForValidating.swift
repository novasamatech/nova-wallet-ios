import Foundation
import SubstrateSdk

protocol StakingActivityForValidating {
    func hasDirectStaking(for completion: @escaping (Result<Bool, Error>) -> Void)
}

final class StakingActivityForValidation {
    let accountId: AccountId
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    init(
        accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.accountId = accountId
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }
}

extension StakingActivityForValidation: StakingActivityProviding {
    func hasDirectStaking(for completion: @escaping (Result<Bool, Error>) -> Void) {
        hasDirectStaking(
            for: accountId,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue,
            completion: completion
        )
    }
}

extension StakingActivityForValidation: StakingActivityForValidating {
    convenience init?(
        wallet: MetaAccountModel,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
            return nil
        }

        self.init(
            accountId: selectedAccount.accountId,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )
    }
}
