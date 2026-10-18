import Foundation
import BigInt
import Operation_iOS

struct SubtensorSubnetsInfo: Equatable {
    let subnets: [SubtensorPallet.DynamicInfo]
    let prices: [UInt16: Balance]
    let subtokenEnabled: Set<UInt16>
}

protocol SubtensorSubnetsOperationFactoryProtocol: AnyObject {
    func createSubnetsInfoWrapper() -> CompoundOperationWrapper<SubtensorSubnetsInfo>

    func createSubnetInfoWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorSubnetsInfo>
}

final class SubtensorSubnetsOperationFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

extension SubtensorSubnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol {
    func createSubnetsInfoWrapper() -> CompoundOperationWrapper<SubtensorSubnetsInfo> {
        let dynamicInfoWrapper = operationFactory.createAllDynamicInfoWrapper(at: nil)
        let pricesWrapper = operationFactory.createAlphaPricesWrapper()
        let operationFactory = operationFactory

        let subtokenWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let netuids = try dynamicInfoWrapper.targetOperation
                .extractNoCancellableResultData()
                .compactMap { $0?.netuid }

            return operationFactory.createSubtokenEnabledWrapper(for: netuids)
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

    func createSubnetInfoWrapper(for netuid: UInt16) -> CompoundOperationWrapper<SubtensorSubnetsInfo> {
        let dynamicInfoWrapper = operationFactory.createDynamicInfoWrapper(for: netuid)
        let priceWrapper = operationFactory.createAlphaPriceWrapper(for: netuid, blockHash: nil)
        let subtokenWrapper = operationFactory.createSubtokenEnabledWrapper(for: [netuid])

        let mergeOperation = ClosureOperation<SubtensorSubnetsInfo> {
            let dynamicInfo = try dynamicInfoWrapper.targetOperation.extractNoCancellableResultData()
            let price = try priceWrapper.targetOperation.extractNoCancellableResultData()
            let subtokenEnabled = try subtokenWrapper.targetOperation.extractNoCancellableResultData()

            guard let dynamicInfo else {
                return SubtensorSubnetsInfo(subnets: [], prices: [:], subtokenEnabled: [])
            }

            return SubtensorSubnetsInfo(
                subnets: [dynamicInfo],
                prices: [netuid: price],
                subtokenEnabled: subtokenEnabled
            )
        }

        mergeOperation.addDependency(dynamicInfoWrapper.targetOperation)
        mergeOperation.addDependency(priceWrapper.targetOperation)
        mergeOperation.addDependency(subtokenWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dynamicInfoWrapper.allOperations + priceWrapper.allOperations + subtokenWrapper.allOperations
        )
    }
}
