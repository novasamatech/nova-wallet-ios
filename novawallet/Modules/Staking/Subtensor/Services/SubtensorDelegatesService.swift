import Foundation
import Operation_iOS

struct SubtensorDelegate: Equatable {
    let info: SubtensorStakingPallet.DelegateInfo
    let identity: AccountIdentity?
}

protocol SubtensorDelegatesServiceProtocol: AnyObject {
    func fetchDelegates(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<[SubtensorDelegate], Error>) -> Void
    )
}

final class SubtensorDelegatesService: SubtensorSessionCachingService<[SubtensorDelegate]> {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol

    init(
        operationFactory: SubtensorApiOperationFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationFactory = operationFactory
        self.identityProxyFactory = identityProxyFactory

        super.init(operationQueue: operationQueue, logger: logger)
    }

    // get_delegates ships a multi-megabyte payload taking tens of seconds on public finney nodes,
    // so the operation factory must be created with an extended rpc timeout; if payloads outgrow
    // the timeout the fallbacks are get_selective_metagraph or StakingHotkeys key enumeration
    override func createFetchWrapper() -> CompoundOperationWrapper<[SubtensorDelegate]> {
        let delegatesWrapper = operationFactory.createDelegatesWrapper()

        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId {
            try delegatesWrapper.targetOperation
                .extractNoCancellableResultData()
                .map(\.delegateSs58)
        }

        identityWrapper.addDependency(wrapper: delegatesWrapper)

        let mergeOperation = ClosureOperation<[SubtensorDelegate]> {
            let delegates = try delegatesWrapper.targetOperation.extractNoCancellableResultData()

            let identities = (try? identityWrapper.targetOperation.extractNoCancellableResultData()) ?? [:]

            return delegates.map { delegate in
                SubtensorDelegate(
                    info: delegate,
                    identity: identities[delegate.delegateSs58]
                )
            }
        }

        mergeOperation.addDependency(identityWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: delegatesWrapper.allOperations + identityWrapper.allOperations
        )
    }
}

extension SubtensorDelegatesService: SubtensorDelegatesServiceProtocol {
    func fetchDelegates(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<[SubtensorDelegate], Error>) -> Void
    ) {
        fetch(runningCompletionIn: queue, completion: completion)
    }
}
