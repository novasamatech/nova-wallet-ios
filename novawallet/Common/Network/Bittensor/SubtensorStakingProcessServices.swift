import Foundation

struct SubtensorStakingProcessServices {
    let bittensorApiOperationFactory: BittensorApiOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let subnetMarketsService: SubtensorSubnetMarketsServiceProtocol
    let costBasisService: SubtensorCostBasisServiceProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let stakeStateSourceFactory: SubtensorStakeStateSourceFactoryProtocol
}

extension SubtensorStakingProcessServices {
    static let shared: SubtensorStakingProcessServices = {
        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorAuthorizedTransport.shared,
            cache: BittensorApiResponseCache(operationQueue: OperationManagerFacade.sharedDefaultQueue),
            logger: Logger.shared
        )

        return SubtensorStakingProcessServices(
            bittensorApiOperationFactory: apiOperationFactory,
            subnetLogosProvider: SubtensorConfigProvider(url: ApplicationConfig.shared.bittensorConfigURL),
            subnetMarketsService: SubtensorSubnetMarketsService(coingeckoOperationFactory: CoingeckoOperationFactory()),
            costBasisService: SubtensorCostBasisService(
                apiOperationFactory: apiOperationFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                eventCenter: EventCenter.shared
            ),
            catalogueService: SubtensorSubnetCatalogueService(apiOperationFactory: apiOperationFactory),
            stakeStateSourceFactory: SubtensorStakeStateSourceFactory(
                eventCenter: EventCenter.shared,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                logger: Logger.shared
            )
        )
    }()

    func createYieldService(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorYieldServiceProtocol {
        SubtensorYieldService(
            apiOperationFactory: bittensorApiOperationFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createMaxApyProvider(
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorMaxApyProviderProtocol {
        SubtensorMaxApyProvider(
            apiOperationFactory: bittensorApiOperationFactory,
            yieldService: createYieldService(operationQueue: operationQueue, logger: logger),
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createAlphaPriceProvider(
        chainOperationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) -> SubtensorAlphaPriceProviderProtocol {
        SubtensorAlphaPriceProvider(
            catalogueService: catalogueService,
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
            alphaPriceProvider: createAlphaPriceProvider(
                chainOperationFactory: chainOperationFactory,
                operationQueue: operationQueue,
                logger: logger
            ),
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
