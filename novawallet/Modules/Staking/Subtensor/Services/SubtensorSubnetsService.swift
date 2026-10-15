import Foundation
import BigInt
import Operation_iOS

struct SubtensorSubnetsInfo: Equatable {
    let subnets: [SubtensorStakingPallet.DynamicInfo]
    let prices: [UInt16: Balance]
    let subtokenEnabled: Set<UInt16>
}

protocol SubtensorSubnetsServiceProtocol: AnyObject {
    func createSubnetsInfoWrapper() -> CompoundOperationWrapper<SubtensorSubnetsInfo>
}

final class SubtensorSubnetsService {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

extension SubtensorSubnetsService: SubtensorSubnetsServiceProtocol {
    func createSubnetsInfoWrapper() -> CompoundOperationWrapper<SubtensorSubnetsInfo> {
        let dynamicInfoWrapper = operationFactory.createAllDynamicInfoWrapper(at: nil)
        let pricesWrapper = operationFactory.createAlphaPricesWrapper(at: nil)
        let operationFactory = operationFactory

        let subtokenWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
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

            let prices = subnetPrices.reduce(into: [UInt16: Balance]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            return SubtensorSubnetsInfo(
                subnets: dynamicInfos.compactMap { $0 },
                prices: prices,
                subtokenEnabled: subtokenEnabled
            )
        }

        mergeOperation.addDependency(dynamicInfoWrapper.targetOperation)
        mergeOperation.addDependency(pricesWrapper.targetOperation)
        mergeOperation.addDependency(subtokenWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dynamicInfoWrapper.allOperations + pricesWrapper.allOperations +
                subtokenWrapper.allOperations
        )
    }
}
