import Foundation
import Operation_iOS

final class SubtensorAlphaPriceOperationFactory {
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let chainOperationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol,
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.catalogueOperationFactory = catalogueOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorAlphaPriceOperationFactory {
    static func createFillWrapper(
        for netuids: Set<UInt16>,
        catalogueResult: Result<SubtensorSubnetCatalogue, Error>,
        catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol,
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

        let namedCatalogue = catalogue ?? catalogueOperationFactory.cachedCatalogue().value
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

extension SubtensorAlphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol {
    func createPricesWrapper(for netuids: Set<UInt16>) -> CompoundOperationWrapper<SubtensorAlphaPrices> {
        let catalogueWrapper = catalogueOperationFactory.createCatalogueWrapper()
        let catalogueOperationFactory = catalogueOperationFactory
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
                    catalogueOperationFactory: catalogueOperationFactory,
                    chainOperationFactory: chainOperationFactory,
                    logger: logger
                )
            }

        pricesWrapper.addDependency(operations: [catalogueOperation])

        return pricesWrapper.insertingHead(operations: catalogueWrapper.allOperations + [catalogueOperation])
    }

    func cachedPrices() -> SubtensorAlphaPrices? {
        guard case let .fresh(catalogue) = catalogueOperationFactory.cachedCatalogue() else {
            return nil
        }

        let taoPerAlpha = catalogue.freshTaoPerAlpha

        guard !taoPerAlpha.isEmpty || catalogue.subnets.isEmpty else {
            return nil
        }

        return SubtensorAlphaPrices(catalogue: catalogue, taoPerAlpha: taoPerAlpha)
    }
}
