import Foundation
import Operation_iOS

typealias FeatureSupportCheckerClosure = (Bool) -> Void

protocol FeatureSupportCheckerProtocol {
    func checkSellSupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    )

    func checkCardSupport(
        for wallet: MetaAccountModel,
        completion: @escaping FeatureSupportCheckerClosure
    )
}

final class FeatureSupportChecker {
    let operationQueue: OperationQueue
    let delayedCallExecRepository: WalletDelayedExecutionRepositoryProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        delayedCallExecRepository = WalletDelayedExecutionRepository(
            userStorageFacade: userStorageFacade
        )
    }
}

private extension FeatureSupportChecker {
    func createDelayedCallWalletWrapper(
        for wallet: MetaAccountModel,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Bool> {
        let execFetchWrapper = delayedCallExecRepository.createVerifier()
        let verifyOperation = ClosureOperation<Bool> {
            let verifier = try execFetchWrapper.targetOperation.extractNoCancellableResultData()

            return !verifier.executesCallWithDelay(wallet, chain: chain)
        }

        verifyOperation.addDependency(execFetchWrapper.targetOperation)

        return execFetchWrapper.insertingTail(operation: verifyOperation)
    }

    func executeAccountExistenceAndDelay(
        wallet: MetaAccountModel,
        chain: ChainModel,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        guard wallet.fetch(for: chain.accountRequest()) != nil else {
            completion(false)
            return
        }

        let checkWrapper = createDelayedCallWalletWrapper(
            for: wallet,
            chain: chain
        )

        execute(
            wrapper: checkWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(hasSupport):
                completion(hasSupport)
            case .failure:
                completion(false)
            }
        }
    }
}

extension FeatureSupportChecker: FeatureSupportCheckerProtocol {
    func checkSellSupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        executeAccountExistenceAndDelay(
            wallet: wallet,
            chain: chainAsset.chain,
            completion: completion
        )
    }

    func checkCardSupport(
        for wallet: MetaAccountModel,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        guard let polkadotChain = chainRegistry.getChain(for: KnowChainId.polkadot) else {
            completion(false)
            return
        }

        executeAccountExistenceAndDelay(
            wallet: wallet,
            chain: polkadotChain,
            completion: completion
        )
    }
}
