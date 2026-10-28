import Foundation
import Operation_iOS
import SubstrateSdk

extension SubtensorShieldExtrinsicFactory {
    struct Timing {
        let nonce: UInt32
        let era: ExtrinsicEraParameters
    }

    func createTimingWrapper(
        after authorizationOperation: BaseOperation<Void>
    ) -> CompoundOperationWrapper<Timing> {
        let timingWrapper = OperationCombiningService<Timing>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            try authorizationOperation.extractNoCancellableResultData()

            let nonceWrapper = self.createNonceWrapper()
            let eraWrapper = self.createEraWrapper()
            let bestNumberWrapper = self.createBestNumberWrapper()

            let timingOperation = ClosureOperation<Timing> {
                let era = try eraWrapper.targetOperation.extractNoCancellableResultData()
                let bestNumber = try bestNumberWrapper.targetOperation.extractNoCancellableResultData()

                guard bestNumber <= era.blockNumber + SubtensorShieldConstants.maxFinalityLag else {
                    throw SubtensorShieldError.finalityLag(bestNumber - era.blockNumber)
                }

                return Timing(
                    nonce: try nonceWrapper.targetOperation.extractNoCancellableResultData(),
                    era: era
                )
            }

            timingOperation.addDependency(nonceWrapper.targetOperation)
            timingOperation.addDependency(eraWrapper.targetOperation)
            timingOperation.addDependency(bestNumberWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: timingOperation,
                dependencies: nonceWrapper.allOperations + eraWrapper.allOperations + bestNumberWrapper.allOperations
            )
        }

        timingWrapper.addDependency(operations: [authorizationOperation])

        return timingWrapper
    }
}

private extension SubtensorShieldExtrinsicFactory {
    func createBestNumberWrapper() -> CompoundOperationWrapper<BlockNumber> {
        let headerOperation = JSONRPCListOperation<Block.Header>(engine: connection, method: RPCMethod.getBlockHeader)

        return FinalizedHeaderOperationFactory.createBlockNumberWrapper(
            for: CompoundOperationWrapper(targetOperation: headerOperation)
        )
    }
}
