import Foundation
import Operation_iOS

final class SubtensorSubnetCatalogueService {
    static let atomicScale = 9

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.logger = logger
    }
}

private extension SubtensorSubnetCatalogueService {
    struct Stamps {
        let metadata: SubtensorBackendStamp
        let prices: SubtensorBackendStamp
    }

    static func makeCatalogue(
        from response: BittensorApiResult<BittensorApi.SubnetCollection>,
        logger: LoggerProtocol
    ) throws -> SubtensorSubnetCatalogue {
        let components = response.value.meta.components

        let stamps = Stamps(
            metadata: SubtensorBackendStamp(
                component: components.subnetMetadata,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            prices: SubtensorBackendStamp(
                component: components.alphaPrices,
                isFromExpiredCache: response.isFromExpiredCache
            )
        )

        var listedNetuids: Set<UInt16> = []
        var subnets: [SubtensorCatalogueSubnet] = []

        for (index, item) in response.value.items.enumerated() {
            guard item.netuid != SubtensorStakingPallet.rootNetuid, !listedNetuids.contains(item.netuid) else {
                logger.warning("Skipped the subnet catalogue row items[\(index)] with netuid \(item.netuid)")
                continue
            }

            listedNetuids.insert(item.netuid)

            try subnets.append(makeSubnet(item, stamps: stamps))
        }

        return SubtensorSubnetCatalogue(subnets: subnets)
    }

    static func makeSubnet(_ item: BittensorApi.Subnet, stamps: Stamps) throws -> SubtensorCatalogueSubnet {
        try SubtensorCatalogueSubnet(
            netuid: item.netuid,
            name: item.name,
            symbol: item.symbol,
            networkRegisteredAt: item.networkRegisteredAt,
            taoReserve: BittensorApiDecimal.atomic(item.taoReserve, scale: atomicScale),
            alphaReserve: BittensorApiDecimal.atomic(item.alphaReserve, scale: atomicScale),
            alphaOutstanding: BittensorApiDecimal.atomic(item.alphaOutstanding, scale: atomicScale),
            taoPerAlpha: BittensorApiDecimal.atomic(item.taoPerAlpha, scale: atomicScale),
            metadataStamp: stamps.metadata,
            pricesStamp: stamps.prices
        )
    }
}

extension SubtensorSubnetCatalogueService: SubtensorSubnetCatalogueServiceProtocol {
    func createCatalogueWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue> {
        let responseWrapper = apiOperationFactory.createSubnetsWrapper()
        let logger = logger

        let catalogueOperation = ClosureOperation<SubtensorSubnetCatalogue> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeCatalogue(from: response, logger: logger)
        }

        catalogueOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: catalogueOperation)
    }

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue> {
        apiOperationFactory.peekSubnets().map { try Self.makeCatalogue(from: $0, logger: logger) }
    }
}
