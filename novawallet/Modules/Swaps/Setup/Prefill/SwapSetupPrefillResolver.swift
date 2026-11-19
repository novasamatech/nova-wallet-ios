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
    func createInitStateWrapper(for wallet: MetaAccountModel) -> CompoundOperationWrapper<SwapSetupInitState> {
        let savedPairWrapper = createResolutionWrapper(for: lastPairStore.lastPair, wallet: wallet)

        let resultWrapper = OperationCombiningService<SwapSetupInitState>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            if let initState = try savedPairWrapper.targetOperation.extractNoCancellableResultData() {
                return .createWithResult(initState)
            }

            return self.createConfigPairInitStateWrapper(for: wallet)
        }

        resultWrapper.addDependency(wrapper: savedPairWrapper)

        return resultWrapper.insertingHead(operations: savedPairWrapper.allOperations)
    }

    func createConfigPairInitStateWrapper(
        for wallet: MetaAccountModel
    ) -> CompoundOperationWrapper<SwapSetupInitState> {
        let configWrapper = globalConfigProvider.createConfigWrapper()

        let resolutionWrapper = OperationCombiningService<SwapSetupInitState?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let configPair: SwapAssetPairId?

            do {
                configPair = try configWrapper.targetOperation.extractNoCancellableResultData().defaultSwapPair
            } catch {
                self.logger.warning("Swap default pair unavailable: \(error)")
                configPair = nil
            }

            return self.createResolutionWrapper(for: configPair, wallet: wallet)
        }

        resolutionWrapper.addDependency(wrapper: configWrapper)

        let mappingOperation = ClosureOperation<SwapSetupInitState> {
            try resolutionWrapper.targetOperation.extractNoCancellableResultData() ??
                SwapSetupInitState(payChainAsset: nil)
        }

        mappingOperation.addDependency(resolutionWrapper.targetOperation)

        return resolutionWrapper
            .insertingHead(operations: configWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func createResolutionWrapper(
        for pair: SwapAssetPairId?,
        wallet: MetaAccountModel
    ) -> CompoundOperationWrapper<SwapSetupInitState?> {
        guard let pair else {
            return .createWithResult(nil)
        }

        let chainIds = Set([pair.pay.chainId, pair.receive.chainId])
        let chainWrappers = chainIds.map { chainRegistry.asyncWaitChainWrapper(for: $0) }

        let mappingOperation = ClosureOperation<SwapSetupInitState?> {
            let chains = try chainWrappers.compactMap { try $0.targetOperation.extractNoCancellableResultData() }
            let chainsById = chains.reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }

            return Self.resolveInitState(from: pair, chains: chainsById, wallet: wallet)
        }

        chainWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: chainWrappers.flatMap(\.allOperations)
        )
    }

    static func resolveInitState(
        from pair: SwapAssetPairId,
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel
    ) -> SwapSetupInitState? {
        guard
            let payChainAsset = resolveChainAsset(pair.pay, chains: chains, wallet: wallet),
            let receiveChainAsset = resolveChainAsset(pair.receive, chains: chains, wallet: wallet),
            payChainAsset.chainAssetId != receiveChainAsset.chainAssetId else {
            return nil
        }

        return SwapSetupInitState(payChainAsset: payChainAsset, receiveChainAsset: receiveChainAsset)
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

        let wrapper = createInitStateWrapper(for: wallet)

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
