import Foundation
import BigInt
import Operation_iOS

struct SubtensorSubnetsInfo: Equatable {
    let subnets: [SubtensorStakingPallet.DynamicInfo]
    let prices: [UInt16: Balance]
    let subtokenEnabled: Set<UInt16>
    /// chain-wide, governance-mutable; falls back to the runtime default while unset
    let ownerCut: UInt16
}

protocol SubtensorSubnetsServiceProtocol: AnyObject {
    func fetchSubnetsInfo(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorSubnetsInfo, Error>) -> Void
    )
}

final class SubtensorSubnetsService: SubtensorSessionCachingService<SubtensorSubnetsInfo> {
    let operationFactory: SubtensorApiOperationFactoryProtocol

    init(
        operationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationFactory = operationFactory

        super.init(operationQueue: operationQueue, logger: logger)
    }

    override func createFetchWrapper() -> CompoundOperationWrapper<SubtensorSubnetsInfo> {
        let dynamicInfoWrapper = operationFactory.createAllDynamicInfoWrapper()
        let pricesWrapper = operationFactory.createAlphaPricesWrapper()
        let ownerCutWrapper = operationFactory.createSubnetOwnerCutWrapper()

        let subtokenWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let netuids = try dynamicInfoWrapper.targetOperation
                .extractNoCancellableResultData()
                .compactMap { $0?.netuid }

            return operationFactory.createSubtokenEnabledWrapper(for: netuids, blockHash: nil)
        }

        subtokenWrapper.addDependency(wrapper: dynamicInfoWrapper)

        let mergeOperation = ClosureOperation<SubtensorSubnetsInfo> {
            let dynamicInfos = try dynamicInfoWrapper.targetOperation.extractNoCancellableResultData()
            let subnetPrices = try pricesWrapper.targetOperation.extractNoCancellableResultData()
            let subtokenEnabled = try subtokenWrapper.targetOperation.extractNoCancellableResultData()
            // SubnetOwnerCut is ValueQuery and reads as null on live finney, so the runtime
            // default stands in until governance sets it
            let ownerCut = try ownerCutWrapper.targetOperation.extractNoCancellableResultData()
                ?? SubtensorStakingPallet.defaultSubnetOwnerCut

            let prices = subnetPrices.reduce(into: [UInt16: Balance]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            return SubtensorSubnetsInfo(
                subnets: dynamicInfos.compactMap { $0 },
                prices: prices,
                subtokenEnabled: subtokenEnabled,
                ownerCut: ownerCut
            )
        }

        mergeOperation.addDependency(dynamicInfoWrapper.targetOperation)
        mergeOperation.addDependency(pricesWrapper.targetOperation)
        mergeOperation.addDependency(subtokenWrapper.targetOperation)
        mergeOperation.addDependency(ownerCutWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dynamicInfoWrapper.allOperations + pricesWrapper.allOperations +
                subtokenWrapper.allOperations + ownerCutWrapper.allOperations
        )
    }
}

extension SubtensorSubnetsService: SubtensorSubnetsServiceProtocol {
    func fetchSubnetsInfo(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorSubnetsInfo, Error>) -> Void
    ) {
        fetch(runningCompletionIn: queue, completion: completion)
    }
}
