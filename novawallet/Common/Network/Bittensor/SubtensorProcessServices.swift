import Foundation

struct SubtensorProcessServices {
    let bittensorApiOperationFactory: BittensorApiOperationFactoryProtocol
    let subnetLogosProvider: SubtensorConfigProviding
    let subnetMarketsOperationFactory: SubtensorSubnetMarketsOperationFactoryProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let stakeStateSourceFactory: SubtensorStakeStateSourceFactoryProtocol
}

extension SubtensorProcessServices {
    static let shared: SubtensorProcessServices = {
        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorAuthorizedTransport.shared,
            cache: BittensorApiResponseCache(operationQueue: OperationManagerFacade.sharedDefaultQueue),
            logger: Logger.shared
        )

        return SubtensorProcessServices(
            bittensorApiOperationFactory: apiOperationFactory,
            subnetLogosProvider: SubtensorConfigProvider(url: ApplicationConfig.shared.bittensorConfigURL),
            subnetMarketsOperationFactory: SubtensorSubnetMarketsOperationFactory(
                coingeckoOperationFactory: CoingeckoOperationFactory()
            ),
            costBasisService: SubtensorCostBasisService(
                apiOperationFactory: apiOperationFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                eventCenter: EventCenter.shared
            ),
            catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactory(
                apiOperationFactory: apiOperationFactory
            ),
            stakeStateSourceFactory: SubtensorStakeStateSourceFactory(
                eventCenter: EventCenter.shared,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                logger: Logger.shared
            )
        )
    }()

    func createYieldOperationFactory(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorYieldOperationFactoryProtocol {
        SubtensorYieldOperationFactory(
            apiOperationFactory: bittensorApiOperationFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createMaxApyOperationFactory(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorMaxApyOperationFactoryProtocol {
        SubtensorMaxApyOperationFactory(
            apiOperationFactory: bittensorApiOperationFactory,
            yieldOperationFactory: createYieldOperationFactory(operationQueue: operationQueue, logger: logger),
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createAlphaPriceOperationFactory(
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorAlphaPriceOperationFactoryProtocol {
        SubtensorAlphaPriceOperationFactory(
            catalogueOperationFactory: catalogueOperationFactory,
            chainOperationFactory: chainOperationFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createCataloguePricingTracker(
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorCataloguePricingTracker {
        SubtensorCataloguePricingTracker(
            alphaPriceOperationFactory: createAlphaPriceOperationFactory(
                chainOperationFactory: chainOperationFactory,
                operationQueue: operationQueue,
                logger: logger
            ),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
