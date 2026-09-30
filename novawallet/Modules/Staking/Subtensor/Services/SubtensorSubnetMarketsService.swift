import Foundation
import Operation_iOS

final class SubtensorSubnetMarketsService: SubtensorSessionCachingService<SubtensorSubnetMarkets> {
    static let category = "bittensor-subnets"

    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol

    private let callbackQueue = DispatchQueue(label: "com.novawallet.subtensor.markets.\(UUID().uuidString)")

    init(
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.coingeckoOperationFactory = coingeckoOperationFactory

        super.init(operationQueue: operationQueue, logger: logger)
    }

    override func createFetchWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets> {
        let fetchOperation = coingeckoOperationFactory.fetchMarkets(category: Self.category, currency: .usd)

        let marketsOperation = ClosureOperation<SubtensorSubnetMarkets> {
            let data = try fetchOperation.extractNoCancellableResultData()
            let markets = try JSONDecoder().decode(SubtensorSubnetMarkets.self, from: data)

            guard !markets.byNetuid.isEmpty else {
                throw CommonError.dataCorruption
            }

            return markets
        }

        marketsOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: marketsOperation, dependencies: [fetchOperation])
    }
}

extension SubtensorSubnetMarketsService: SubtensorSubnetMarketsServiceProtocol {
    func createMarketsWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets> {
        let callbackQueue = callbackQueue

        let marketsOperation = AsyncClosureOperation<SubtensorSubnetMarkets> { [weak self] completion in
            guard let self else {
                completion(.failure(BaseOperationError.parentOperationCancelled))
                return
            }

            fetch(runningCompletionIn: callbackQueue, completion: completion)
        }

        return CompoundOperationWrapper(targetOperation: marketsOperation)
    }
}
