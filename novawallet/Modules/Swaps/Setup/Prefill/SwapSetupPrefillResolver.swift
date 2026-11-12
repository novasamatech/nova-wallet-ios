import Foundation
import Operation_iOS

protocol SwapSetupPrefillResolving: AnyObject {
    func resolveInitState(
        for wallet: MetaAccountModel,
        completion: @escaping (SwapSetupInitState) -> Void
    )

    func cancel()
}

final class SwapSetupPrefillResolver {
    let lastPairStore: SwapLastPairStoring
    let globalConfigProvider: GlobalConfigProviding
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let callStore = CancellableCallStore()

    init(
        lastPairStore: SwapLastPairStoring,
        globalConfigProvider: GlobalConfigProviding,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.lastPairStore = lastPairStore
        self.globalConfigProvider = globalConfigProvider
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: Private

private extension SwapSetupPrefillResolver {
    func createCandidatesWrapper() -> CompoundOperationWrapper<[SwapAssetPairId]> {
        let savedPair = lastPairStore.lastPair
        let configWrapper = globalConfigProvider.createConfigWrapper()

        let mappingOperation = ClosureOperation<[SwapAssetPairId]> { [weak self] in
            let configPair: SwapAssetPairId?

            do {
                configPair = try configWrapper.targetOperation.extractNoCancellableResultData().defaultSwapPair
            } catch {
                self?.logger.warning("Swap default pair unavailable: \(error)")
                configPair = nil
            }

            return [savedPair, configPair].compactMap { $0 }
        }

        mappingOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: mappingOperation)
    }

    func createResolutionWrapper(
        for candidatesWrapper: CompoundOperationWrapper<[SwapAssetPairId]>,
        wallet: MetaAccountModel
    ) -> CompoundOperationWrapper<SwapSetupInitState> {
        let resolutionWrapper = OperationCombiningService<SwapSetupInitState>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [chainRegistry] in
            let candidates = try candidatesWrapper.targetOperation.extractNoCancellableResultData()
            let chainIds = Set(candidates.flatMap { [$0.pay.chainId, $0.receive.chainId] })

            let chainWrappers = chainIds.map { chainRegistry.asyncWaitChainWrapper(for: $0) }

            let mappingOperation = ClosureOperation<SwapSetupInitState> {
                let chains = try chainWrappers.compactMap { try $0.targetOperation.extractNoCancellableResultData() }
                let chainsById = chains.reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }

                return Self.resolveInitState(from: candidates, chains: chainsById, wallet: wallet)
            }

            chainWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: chainWrappers.flatMap(\.allOperations)
            )
        }

        resolutionWrapper.addDependency(wrapper: candidatesWrapper)

        return resolutionWrapper.insertingHead(operations: candidatesWrapper.allOperations)
    }

    static func resolveInitState(
        from candidates: [SwapAssetPairId],
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel
    ) -> SwapSetupInitState {
        for candidate in candidates {
            guard
                let payChainAsset = resolveChainAsset(candidate.pay, chains: chains, wallet: wallet),
                let receiveChainAsset = resolveChainAsset(candidate.receive, chains: chains, wallet: wallet),
                payChainAsset.chainAssetId != receiveChainAsset.chainAssetId else {
                continue
            }

            return SwapSetupInitState(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset)
        }

        return SwapSetupInitState(payChainAsset: nil)
    }

    static func resolveChainAsset(
        _ chainAssetId: ChainAssetId,
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel
    ) -> ChainAsset? {
        guard
            let chain = chains[chainAssetId.chainId],
            let chainAsset = chain.chainAsset(for: chainAssetId.assetId),
            wallet.fetch(for: chain.accountRequest()) != nil else {
            return nil
        }

        return chainAsset
    }
}

// MARK: SwapSetupPrefillResolving

extension SwapSetupPrefillResolver: SwapSetupPrefillResolving {
    func resolveInitState(
        for wallet: MetaAccountModel,
        completion: @escaping (SwapSetupInitState) -> Void
    ) {
        callStore.cancel()

        let candidatesWrapper = createCandidatesWrapper()
        let wrapper = createResolutionWrapper(for: candidatesWrapper, wallet: wallet)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(initState):
                completion(initState)
            case let .failure(error):
                self?.logger.error("Swap prefill failed: \(error)")
                completion(SwapSetupInitState(payChainAsset: nil))
            }
        }
    }

    func cancel() {
        callStore.cancel()
    }
}
