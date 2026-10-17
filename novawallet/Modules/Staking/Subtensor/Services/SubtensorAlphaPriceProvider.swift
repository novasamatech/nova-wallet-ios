import Foundation
import Operation_iOS

final class SubtensorAlphaPriceProvider {
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let chainOperationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.chainOperationFactory = chainOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorAlphaPriceProvider {
    static func createFillWrapper(
        for netuids: Set<UInt16>,
        catalogueResult: Result<SubtensorSubnetCatalogue, Error>,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<SubtensorAlphaPrices> {
        let catalogue = try? catalogueResult.get()
        let backend = catalogue?.freshTaoPerAlpha ?? [:]
        let missing = netuids.subtracting(backend.keys)

        guard !missing.isEmpty else {
            return .createWithResult(SubtensorAlphaPrices(catalogue: catalogue, taoPerAlpha: backend))
        }

        if case let .failure(error) = catalogueResult {
            logger.warning("Subnet catalogue unavailable, pricing \(missing.sorted()) from the chain: \(error)")
        }

        let namedCatalogue = catalogue ?? catalogueService.cachedCatalogue().value
        let chainWrapper = chainOperationFactory.createAlphaPricesWrapper()

        let mergeOperation = ClosureOperation<SubtensorAlphaPrices> {
            do {
                let chainPrices = try chainWrapper.targetOperation.extractNoCancellableResultData()

                let taoPerAlpha = chainPrices.reduce(into: backend) { accum, subnet in
                    if missing.contains(subnet.netuid) {
                        accum[subnet.netuid] = subnet.price
                    }
                }

                return SubtensorAlphaPrices(catalogue: namedCatalogue, taoPerAlpha: taoPerAlpha)
            } catch {
                guard namedCatalogue != nil else {
                    throw error
                }

                logger.warning("Chain alpha prices unavailable: \(error)")

                return SubtensorAlphaPrices(catalogue: namedCatalogue, taoPerAlpha: backend)
            }
        }

        mergeOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mergeOperation)
    }
}

extension SubtensorAlphaPriceProvider: SubtensorAlphaPriceProviderProtocol {
    func createPricesWrapper(for netuids: Set<UInt16>) -> CompoundOperationWrapper<SubtensorAlphaPrices> {
        let catalogueWrapper = catalogueService.createCatalogueWrapper()
        let catalogueService = catalogueService
        let chainOperationFactory = chainOperationFactory
        let logger = logger

        let catalogueOperation = ClosureOperation<Result<SubtensorSubnetCatalogue, Error>> {
            Result { try catalogueWrapper.targetOperation.extractNoCancellableResultData() }
        }

        catalogueOperation.addDependency(catalogueWrapper.targetOperation)

        let pricesWrapper: CompoundOperationWrapper<SubtensorAlphaPrices> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let catalogueResult = try catalogueOperation.extractNoCancellableResultData()

                return Self.createFillWrapper(
                    for: netuids,
                    catalogueResult: catalogueResult,
                    catalogueService: catalogueService,
                    chainOperationFactory: chainOperationFactory,
                    logger: logger
                )
            }

        pricesWrapper.addDependency(operations: [catalogueOperation])

        return pricesWrapper.insertingHead(operations: catalogueWrapper.allOperations + [catalogueOperation])
    }

    func cachedPrices() -> SubtensorAlphaPrices? {
        guard case let .fresh(catalogue) = catalogueService.cachedCatalogue() else {
            return nil
        }

        return SubtensorAlphaPrices(catalogue: catalogue, taoPerAlpha: catalogue.freshTaoPerAlpha)
    }
}
