import Foundation
import BigInt
import Operation_iOS

struct SubtensorSubnetsInfo: Equatable {
    let subnets: [SubtensorStakingPallet.DynamicInfo]
    let prices: [UInt16: Balance]
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

        let mergeOperation = ClosureOperation<SubtensorSubnetsInfo> {
            let dynamicInfos = try dynamicInfoWrapper.targetOperation.extractNoCancellableResultData()
            let subnetPrices = try pricesWrapper.targetOperation.extractNoCancellableResultData()

            let prices = subnetPrices.reduce(into: [UInt16: Balance]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            return SubtensorSubnetsInfo(
                subnets: dynamicInfos.compactMap { $0 },
                prices: prices
            )
        }

        mergeOperation.addDependency(dynamicInfoWrapper.targetOperation)
        mergeOperation.addDependency(pricesWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dynamicInfoWrapper.allOperations + pricesWrapper.allOperations
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
