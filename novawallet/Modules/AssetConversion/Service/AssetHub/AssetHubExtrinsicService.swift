import Foundation
import SubstrateSdk
import RobinHood

final class AssetHubExtrinsicService {
    let account: ChainAccountResponse
    let chain: ChainModel
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue = .global()
    ) {
        self.account = account
        self.chain = chain
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.workQueue = workQueue
    }

    private func performSubmition(
        remoteFeeAsset: AssetConversionPallet.AssetId?,
        builderClosure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    ) {
        let extrinsicFactory: ExtrinsicOperationFactoryProtocol

        if let remoteFeeAsset = remoteFeeAsset {
            extrinsicFactory = extrinsicServiceFactory.createOperationFactory(
                account: account,
                chain: chain,
                feeAssetConversionId: remoteFeeAsset
            )
        } else {
            extrinsicFactory = extrinsicServiceFactory.createOperationFactory(
                account: account,
                chain: chain
            )
        }

        let wrapper = extrinsicFactory.submit(builderClosure, signer: signer)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: queue,
            callbackClosure: closure
        )
    }
}

extension AssetHubExtrinsicService: AssetConversionExtrinsicServiceProtocol {
    func submit(
        callArgs: AssetConversion.CallArgs,
        feeAsset: ChainAsset,
        signer: SigningWrapperProtocol,
        runCompletionIn queue: DispatchQueue,
        completion closure: @escaping ExtrinsicSubmitClosure
    ) {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<(ExtrinsicBuilderClosure, AssetConversionPallet.AssetId?)> {
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

            let builderClosure: ExtrinsicBuilderClosure = { builder in
                try AssetHubExtrinsicConverter.addingOperation(
                    to: builder,
                    chain: feeAsset.chain,
                    args: callArgs,
                    codingFactory: codingFactory
                )
            }

            guard !feeAsset.isUtilityAsset else {
                return (builderClosure, nil)
            }

            guard
                let assetId = AssetHubTokensConverter.convertToMultilocation(
                    chainAsset: feeAsset,
                    codingFactory: codingFactory
                ) else {
                throw AssetConversionExtrinsicServiceError.remoteAssetNotFound(feeAsset.chainAssetId)
            }

            return (builderClosure, assetId)
        }

        mappingOperation.addDependency(coderFactoryOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [coderFactoryOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: workQueue
        ) { [weak self] result in
            switch result {
            case let .success((builder, remoteFeeAsset)):
                self?.performSubmition(
                    remoteFeeAsset: remoteFeeAsset,
                    builderClosure: builder,
                    signer: signer,
                    runCompletionIn: queue,
                    completion: closure
                )
            case let .failure(error):
                dispatchInQueueWhenPossible(queue) {
                    closure(.failure(error))
                }
            }
        }
    }
}
