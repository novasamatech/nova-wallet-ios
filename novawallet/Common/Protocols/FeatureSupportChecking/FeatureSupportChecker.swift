import Foundation
import Operation_iOS

typealias FeatureSupportCheckerClosure = (OperationCheckCommonResult) -> Void

protocol FeatureSupportCheckerProtocol {
    func checkSellSupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    )

    func checkBuySupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    )

    func checkCardSupport(
        for wallet: MetaAccountModel,
        completion: @escaping FeatureSupportCheckerClosure
    )
}

extension FeatureSupportCheckerProtocol {
    func checkRampSupport(
        wallet: MetaAccountModel,
        rampActions: [RampAction],
        rampType: RampActionType,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        let filteredActions = rampActions.filter { $0.type == rampType }

        guard !filteredActions.isEmpty else {
            completion(.noRampActions)
            return
        }

        switch rampType {
        case .offRamp:
            checkSellSupport(
                for: wallet,
                chainAsset: chainAsset,
                completion: completion
            )
        case .onRamp:
            checkBuySupport(
                for: wallet,
                chainAsset: chainAsset,
                completion: completion
            )
        }
    }
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

// MARK: - Private

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
        completion: @escaping (Bool) -> Void
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

    func checkSellByWalletTypeSupported(
        _ wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> FeatureSupportCheckResult {
        switch wallet.type {
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .genericLedger:
            .commonResult(.available)
        case .ledger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                .commonResult(.ledgerNotSupported)
            } else {
                .commonResult(.available)
            }
        case .watchOnly:
            .commonResult(.noSigning)
        case .multisig, .proxied:
            .delayedExecutionCheckRequired
        }
    }

    func checkBuyByWalletTypeSupported(
        _ wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> OperationCheckCommonResult {
        switch wallet.type {
        case .secrets, .paritySigner, .polkadotVault, .polkadotVaultRoot, .proxied, .multisig, .genericLedger:
            .available
        case .ledger:
            if let assetRawType = chainAsset.asset.type, case .orml = AssetType(rawValue: assetRawType) {
                .ledgerNotSupported
            } else {
                .available
            }
        case .watchOnly:
            .noSigning
        }
    }
}

// MARK: - FeatureSupportCheckerProtocol

extension FeatureSupportChecker: FeatureSupportCheckerProtocol {
    func checkSellSupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        let checkResult = checkSellByWalletTypeSupported(wallet, chainAsset: chainAsset)

        switch checkResult {
        case let .commonResult(result):
            completion(result)
        case .delayedExecutionCheckRequired:
            executeAccountExistenceAndDelay(
                wallet: wallet,
                chain: chainAsset.chain
            ) { hasSupport in
                let result: OperationCheckCommonResult = hasSupport ? .available : .noSellSupport(wallet, chainAsset)

                completion(result)
            }
        }
    }

    func checkCardSupport(
        for wallet: MetaAccountModel,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        // to get the card one need to be able to operate in Polkadot without delay
        guard
            let polkadotChain = chainRegistry.getChain(for: KnowChainId.polkadot),
            let dotToken = polkadotChain.utilityChainAsset() else {
            completion(.noCardSupport(wallet))
            return
        }

        // to get the card one need to sell tokens first
        let sellCheckResult = checkSellByWalletTypeSupported(wallet, chainAsset: dotToken)

        switch sellCheckResult {
        case let .commonResult(result):
            completion(result)
        case .delayedExecutionCheckRequired:
            executeAccountExistenceAndDelay(
                wallet: wallet,
                chain: polkadotChain
            ) { hasSupport in
                let result: OperationCheckCommonResult = hasSupport ? .available : .noCardSupport(wallet)

                completion(result)
            }
        }
    }

    func checkBuySupport(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        completion: @escaping FeatureSupportCheckerClosure
    ) {
        let result = checkBuyByWalletTypeSupported(wallet, chainAsset: chainAsset)

        completion(result)
    }
}

// MARK: - Private types

private enum FeatureSupportCheckResult {
    case commonResult(OperationCheckCommonResult)
    case delayedExecutionCheckRequired
}
