import Foundation
import RobinHood
import BigInt

final class AssetHubFeeService: AnyCancellableCleaning {
    struct ChainOperationFactory {
        let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
        let conversionOperationFactory: AssetConversionOperationFactoryProtocol
        let conversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    }

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private var factories: ChainOperationFactory?
    private var chainId: ChainModel.Id?
    private var cancellableCall: CancellableCall?
    private var lock = NSLock()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func updateFactories(for asset: ChainAsset) throws -> ChainOperationFactory {
        if asset.chainAssetId.chainId == chainId, let factories = factories {
            return factories
        }

        factories = nil
        chainId = nil

        let chain = asset.chain

        guard let account = wallet.fetch(for: chain.accountRequest()) else {
            throw AssetConversionFeeServiceError.accountMissing
        }

        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw AssetConversionFeeServiceError.chainConnectionMissing
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw AssetConversionFeeServiceError.chainRuntimeMissing
        }

        let extrinsicOperationFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createOperationFactory(
            account: account,
            chain: chain
        )

        let conversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chain,
            runtimeService: runtimeProvider,
            connection: connection,
            operationQueue: operationQueue
        )

        let conversionExtrinsicService = AssetHubExtrinsicService(chain: chain)

        let factories = ChainOperationFactory(
            extrinsicOperationFactory: extrinsicOperationFactory,
            conversionOperationFactory: conversionOperationFactory,
            conversionExtrinsicService: conversionExtrinsicService
        )

        self.factories = factories
        chainId = asset.chainAssetId.chainId

        return factories
    }

    private func performCalculation(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    ) throws {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: asset.chain.chainId) else {
            throw AssetConversionFeeServiceError.chainRuntimeMissing
        }

        guard let utilityAsset = asset.chain.utilityAsset() else {
            throw AssetConversionFeeServiceError.utilityAssetMissing
        }

        let utilityChainAsset = ChainAsset(chain: asset.chain, asset: utilityAsset)

        let factories = try updateFactories(for: asset)

        let nativeFeeWrapper = createNativeFeeWrapper(
            for: callArgs,
            runtimeProvider: runtimeProvider,
            extrinsicOperationFactory: factories.extrinsicOperationFactory,
            conversionExtrinsicService: factories.conversionExtrinsicService
        )

        let universalFeeWrapper: CompoundOperationWrapper<AssetConversion.FeeModel>

        if asset.isUtilityAsset {
            universalFeeWrapper = createNativeTokenFeeCalculationWrapper(using: nativeFeeWrapper)
        } else {
            universalFeeWrapper = createCustomTokenFeeCalculationWrapper(
                in: asset,
                utilityAsset: utilityChainAsset,
                nativeFeeWrapper: nativeFeeWrapper,
                runtimeProvider: runtimeProvider,
                conversionOperationFactory: factories.conversionOperationFactory
            )
        }

        universalFeeWrapper.targetOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(queue) {
                guard let self = self, self.completeOrIgnore(wrapper: universalFeeWrapper) else {
                    return
                }

                do {
                    let model = try universalFeeWrapper.targetOperation.extractNoCancellableResultData()
                    closure(.success(model))
                } catch let error as AssetConversionFeeServiceError {
                    closure(.failure(error))
                } catch {
                    closure(.failure(.calculationFailed("Fee calculation failed \(asset.chain.name): \(error)")))
                }
            }
        }

        cancellableCall = universalFeeWrapper

        operationQueue.addOperations(universalFeeWrapper.allOperations, waitUntilFinished: false)
    }

    private func createNativeFeeWrapper(
        for callArgs: AssetConversion.CallArgs,
        runtimeProvider: RuntimeProviderProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        conversionExtrinsicService: AssetConversionExtrinsicServiceProtocol
    ) -> CompoundOperationWrapper<BigUInt> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let feeWrapper = extrinsicOperationFactory.estimateFeeOperation { builder in
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

            let builderSetupClosure = conversionExtrinsicService.fetchExtrinsicBuilderClosure(
                for: callArgs,
                codingFactory: codingFactory
            )

            return try builderSetupClosure(builder)
        }

        let mappingOperation = ClosureOperation<BigUInt> {
            let feeModel = try feeWrapper.targetOperation.extractNoCancellableResultData()

            guard let fee = BigUInt(feeModel.fee) else {
                throw CommonError.dataCorruption
            }

            return fee
        }

        feeWrapper.addDependency(operations: [coderFactoryOperation])
        mappingOperation.addDependency(feeWrapper.targetOperation)

        return feeWrapper
            .insertingHead(operations: [coderFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }

    private func createNativeTokenFeeCalculationWrapper(
        using nativeFeeWrapper: CompoundOperationWrapper<BigUInt>
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        let resultOperation = ClosureOperation<AssetConversion.FeeModel> {
            let feeAmount = try nativeFeeWrapper.targetOperation.extractNoCancellableResultData()

            return .init(
                totalFee: .init(
                    targetAmount: feeAmount,
                    nativeAmouunt: feeAmount
                ),
                networkFeeAddition: nil
            )
        }

        resultOperation.addDependency(nativeFeeWrapper.targetOperation)

        return nativeFeeWrapper.insertingTail(operation: resultOperation)
    }

    private func createCustomTokenFeeCalculationWrapper(
        in feeAsset: ChainAsset,
        utilityAsset: ChainAsset,
        nativeFeeWrapper: CompoundOperationWrapper<BigUInt>,
        runtimeProvider: RuntimeProviderProtocol,
        conversionOperationFactory: AssetConversionOperationFactoryProtocol
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        let edWrapper = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        ).createAssetBalanceExistenceOperation(
            chainId: utilityAsset.chain.chainId,
            asset: utilityAsset.asset,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )

        let feeWithEdOperation = ClosureOperation<(BigUInt, BigUInt)> {
            let feeAmount = try nativeFeeWrapper.targetOperation.extractNoCancellableResultData()
            let edAmount = try edWrapper.targetOperation.extractNoCancellableResultData().minBalance

            return (feeAmount, edAmount)
        }

        feeWithEdOperation.addDependency(nativeFeeWrapper.targetOperation)
        feeWithEdOperation.addDependency(edWrapper.targetOperation)

        let quoteOperation = createQuoteForCustomTokenWrapper(
            for: feeAsset,
            utilityAsset: utilityAsset,
            conversionOperationFactory: conversionOperationFactory,
            feeWithEdOperation: feeWithEdOperation
        )

        quoteOperation.addDependency(feeWithEdOperation)

        let mergeOperation = ClosureOperation<AssetConversion.FeeModel> {
            let (feeAmount, edAmount) = try feeWithEdOperation.extractNoCancellableResultData()

            let quotes = try quoteOperation.extractNoCancellableResultData()

            return .init(
                totalFee: .init(
                    targetAmount: quotes[0].amountIn,
                    nativeAmouunt: feeAmount + edAmount
                ),
                networkFeeAddition: .init(
                    targetAmount: quotes[1].amountIn,
                    nativeAmouunt: edAmount
                )
            )
        }

        mergeOperation.addDependency(feeWithEdOperation)
        mergeOperation.addDependency(quoteOperation)

        let dependencies = nativeFeeWrapper.allOperations + edWrapper.allOperations +
            [feeWithEdOperation, quoteOperation]

        return .init(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func createQuoteForCustomTokenWrapper(
        for feeAsset: ChainAsset,
        utilityAsset: ChainAsset,
        conversionOperationFactory: AssetConversionOperationFactoryProtocol,
        feeWithEdOperation: BaseOperation<(BigUInt, BigUInt)>
    ) -> BaseOperation<[AssetConversion.Quote]> {
        OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let (fee, edAmount) = try feeWithEdOperation.extractNoCancellableResultData()

            let feeWithAdditionsQuoteWrapper = conversionOperationFactory.quote(
                for: .init(
                    assetIn: feeAsset.chainAssetId,
                    assetOut: utilityAsset.chainAssetId,
                    amount: fee + edAmount,
                    direction: .buy
                )
            )

            let edQuoteWrapper = conversionOperationFactory.quote(
                for: .init(
                    assetIn: feeAsset.chainAssetId,
                    assetOut: utilityAsset.chainAssetId,
                    amount: edAmount,
                    direction: .buy
                )
            )

            return [feeWithAdditionsQuoteWrapper, edQuoteWrapper]
        }.longrunOperation()
    }

    private func completeOrIgnore(wrapper: CompoundOperationWrapper<AssetConversion.FeeModel>) -> Bool {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard cancellableCall === wrapper else {
            return false
        }

        cancellableCall = nil

        return true
    }
}

extension AssetHubFeeService: AssetConversionFeeServiceProtocol {
    func calculate(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    ) {
        do {
            lock.lock()

            defer {
                lock.unlock()
            }

            clear(cancellable: &cancellableCall)

            try performCalculation(
                in: asset,
                callArgs: callArgs,
                runCompletionIn: queue,
                completion: closure
            )
        } catch let error as AssetConversionFeeServiceError {
            dispatchInQueueWhenPossible(queue) {
                closure(.failure(error))
            }
        } catch {
            dispatchInQueueWhenPossible(queue) {
                closure(.failure(.setupFailed("Fee service setup failed for \(asset.chain.name): \(error)")))
            }
        }
    }
}
