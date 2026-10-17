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
    static func makeCatalogue(
        from response: BittensorApiResult<BittensorApi.SubnetCollection>,
        logger: LoggerProtocol
    ) throws -> SubtensorSubnetCatalogue {
        let components = response.value.meta.components

        let metadataStamp = SubtensorBackendStamp(
            component: components.subnetMetadata,
            isFromExpiredCache: response.isFromExpiredCache
        )

        let pricesStamp = SubtensorBackendStamp(
            component: components.alphaPrices,
            isFromExpiredCache: response.isFromExpiredCache
        )

        var listedNetuids: Set<UInt16> = []
        var subnets: [SubtensorCatalogueSubnet] = []

        for (index, item) in response.value.items.enumerated() {
            guard item.netuid != SubtensorStakingPallet.rootNetuid, !listedNetuids.contains(item.netuid) else {
                logger.warning("Skipped the subnet catalogue row items[\(index)] with netuid \(item.netuid)")
                continue
            }

            listedNetuids.insert(item.netuid)

            try subnets.append(makeSubnet(item, metadataStamp: metadataStamp, pricesStamp: pricesStamp))
        }

        return SubtensorSubnetCatalogue(subnets: subnets)
    }

    static func makeSubnet(
        _ item: BittensorApi.Subnet,
        metadataStamp: SubtensorBackendStamp,
        pricesStamp: SubtensorBackendStamp
    ) throws -> SubtensorCatalogueSubnet {
        try SubtensorCatalogueSubnet(
            netuid: item.netuid,
            name: item.name,
            symbol: item.symbol,
            networkRegisteredAt: item.networkRegisteredAt,
            taoReserve: BittensorApiDecimal.atomic(item.taoReserve, scale: atomicScale),
            alphaReserve: BittensorApiDecimal.atomic(item.alphaReserve, scale: atomicScale),
            alphaOutstanding: BittensorApiDecimal.atomic(item.alphaOutstanding, scale: atomicScale),
            taoPerAlpha: BittensorApiDecimal.atomic(item.taoPerAlpha, scale: atomicScale),
            metadataStamp: metadataStamp,
            pricesStamp: pricesStamp
        )
    }
}

extension SubtensorSubnetCatalogueService: SubtensorSubnetCatalogueServiceProtocol {
    func createCatalogueWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue> {
        let logger = logger

        return apiOperationFactory.createSubnetsWrapper().mapped { try Self.makeCatalogue(from: $0, logger: logger) }
    }

    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue> {
        apiOperationFactory.peekSubnets().map { try Self.makeCatalogue(from: $0, logger: logger) }
    }
}
