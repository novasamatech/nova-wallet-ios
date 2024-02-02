import Foundation
import RobinHood
import BigInt

final class AssetHubFeeService: AnyCancellableCleaning {
    let wallet: MetaAccountModel
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let conversionOperationFactory: AssetHubSwapOperationFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private var cancellableCall: CancellableCall?
    private let lock = NSLock()

    init(
        wallet: MetaAccountModel,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        conversionOperationFactory: AssetHubSwapOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.conversionOperationFactory = conversionOperationFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    private func performCalculation(
        in asset: ChainAsset,
        callArgs: AssetConversion.CallArgs,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping AssetConversionFeeServiceClosure
    ) throws {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: asset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let utilityAsset = asset.chain.utilityAsset() else {
            throw AssetConversionFeeServiceError.utilityAssetMissing
        }

        let utilityChainAsset = ChainAsset(chain: asset.chain, asset: utilityAsset)

        let nativeFeeWrapper = createNativeFeeWrapper(
            for: callArgs,
            runtimeProvider: runtimeProvider,
            extrinsicServiceFactory: extrinsicServiceFactory,
            wallet: wallet,
            asset: asset
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
                conversionOperationFactory: conversionOperationFactory
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
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        wallet: MetaAccountModel,
        asset: ChainAsset
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mainFeeOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard let account = wallet.fetch(for: asset.chain.accountRequest()) else {
                throw AssetConversionFeeServiceError.accountMissing
            }

            let coderFactory = try coderFactoryOperation.extractNoCancellableResultData()

            let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol

            if asset.isUtilityAsset {
                extrinsicOperationFactory = extrinsicServiceFactory.createOperationFactory(
                    account: account,
                    chain: asset.chain
                )
            } else {
                guard let assetId = AssetHubTokensConverter.convertToMultilocation(
                    chainAsset: asset,
                    codingFactory: coderFactory
                ) else {
                    throw AssetConversionFeeServiceError.feeAssetConversionFailed
                }

                extrinsicOperationFactory = extrinsicServiceFactory.createOperationFactory(
                    account: account,
                    chain: asset.chain,
                    feeAssetConversionId: assetId
                )
            }

            let feeWrapper = extrinsicOperationFactory.estimateFeeOperation { builder in
                let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

                return try AssetHubExtrinsicConverter.addingOperation(
                    to: builder,
                    chain: asset.chain,
                    args: callArgs,
                    codingFactory: codingFactory
                )
            }

            return [feeWrapper]
        }.longrunOperation()

        let mappingOperation = ClosureOperation<ExtrinsicFeeProtocol> {
            guard let feeModel = try mainFeeOperation.extractNoCancellableResultData().first else {
                throw CommonError.dataCorruption
            }

            return feeModel
        }

        mainFeeOperation.addDependency(coderFactoryOperation)
        mappingOperation.addDependency(mainFeeOperation)

        return .init(
            targetOperation: mappingOperation,
            dependencies: [coderFactoryOperation, mainFeeOperation]
        )
    }

    private func createNativeTokenFeeCalculationWrapper(
        using nativeFeeWrapper: CompoundOperationWrapper<ExtrinsicFeeProtocol>
    ) -> CompoundOperationWrapper<AssetConversion.FeeModel> {
        let resultOperation = ClosureOperation<AssetConversion.FeeModel> {
            let fee = try nativeFeeWrapper.targetOperation.extractNoCancellableResultData()

            let model = AssetConversion.AmountWithNative(targetAmount: fee.amount, nativeAmount: fee.amount)

            return .init(totalFee: model, networkFee: model, networkFeePayer: fee.payer)
        }

        resultOperation.addDependency(nativeFeeWrapper.targetOperation)

        return nativeFeeWrapper.insertingTail(operation: resultOperation)
    }

    private func createCustomTokenFeeCalculationWrapper(
        in feeAsset: ChainAsset,
        utilityAsset: ChainAsset,
        nativeFeeWrapper: CompoundOperationWrapper<ExtrinsicFeeProtocol>,
        runtimeProvider: RuntimeProviderProtocol,
        conversionOperationFactory: AssetHubSwapOperationFactoryProtocol
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
            let feeAmount = try nativeFeeWrapper.targetOperation.extractNoCancellableResultData().amount
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
            let networkFeePayer = try nativeFeeWrapper.targetOperation.extractNoCancellableResultData().payer

            let quotes = try quoteOperation.extractNoCancellableResultData()

            return .init(
                totalFee: .init(
                    targetAmount: quotes[0].amountIn,
                    nativeAmount: feeAmount + edAmount
                ),
                networkFee: .init(
                    targetAmount: quotes[1].amountIn,
                    nativeAmount: feeAmount
                ),
                networkFeePayer: networkFeePayer
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
        conversionOperationFactory: AssetHubSwapOperationFactoryProtocol,
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

            let feeQuoteWrapper = conversionOperationFactory.quote(
                for: .init(
                    assetIn: feeAsset.chainAssetId,
                    assetOut: utilityAsset.chainAssetId,
                    amount: fee,
                    direction: .buy
                )
            )

            return [feeWithAdditionsQuoteWrapper, feeQuoteWrapper]
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
