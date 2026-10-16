import Foundation
import Operation_iOS

final class SubtensorMaxApyProvider {
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.yieldService = yieldService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorMaxApyProvider {
    static func makePairs(
        from response: BittensorApiResult<BittensorApi.RecommendationCollection>,
        logger: LoggerProtocol
    ) -> [SubtensorHotkeySubnet] {
        let classes = response.value.classes

        return (classes.stable + classes.balanced + classes.higherUpside).compactMap { recommendation in
            guard let hotkey = try? recommendation.hotkey.toAccountId(
                using: .substrate(SubstrateConstants.genericAddressPrefix)
            ) else {
                logger.warning("Skipped a recommendation of netuid \(recommendation.netuid) with an undecodable hotkey")
                return nil
            }

            return SubtensorHotkeySubnet(hotkey: hotkey, netuid: recommendation.netuid)
        }
    }
}

extension SubtensorMaxApyProvider: SubtensorMaxApyProviderProtocol {
    func createMaxApyWrapper() -> CompoundOperationWrapper<[UInt16: Decimal]> {
        let responseWrapper = apiOperationFactory.createRecommendationsWrapper()
        let yieldService = yieldService
        let logger = logger

        let maxApyWrapper: CompoundOperationWrapper<[UInt16: Decimal]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let response = try responseWrapper.targetOperation.extractNoCancellableResultData()
                let pairs = Self.makePairs(from: response, logger: logger)
                let yieldWrappers = Set(pairs.map(\.netuid)).map { yieldService.createAlphaYieldsWrapper(for: $0) }

                let maxOperation = ClosureOperation<[UInt16: Decimal]> {
                    var rates: [UInt16: Decimal] = [:]
                    var firstError: Error?

                    for wrapper in yieldWrappers {
                        do {
                            let alphaYields = try wrapper.targetOperation.extractNoCancellableResultData()

                            rates[alphaYields.netuid] = pairs
                                .filter { $0.netuid == alphaYields.netuid }
                                .compactMap { alphaYields.yields[$0.hotkey]?.annualRate }
                                .max()
                        } catch {
                            firstError = firstError ?? error
                        }
                    }

                    if rates.isEmpty, let firstError {
                        throw firstError
                    }

                    return rates
                }

                yieldWrappers.forEach { maxOperation.addDependency($0.targetOperation) }

                return CompoundOperationWrapper(
                    targetOperation: maxOperation,
                    dependencies: yieldWrappers.flatMap(\.allOperations)
                )
            }

        maxApyWrapper.addDependency(wrapper: responseWrapper)

        return maxApyWrapper.insertingHead(operations: responseWrapper.allOperations)
    }
}
