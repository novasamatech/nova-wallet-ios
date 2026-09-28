import Foundation
import Operation_iOS

final class SubtensorSubnetCatalogueService: SubtensorSessionCachingService<SubtensorSubnetCatalogue> {
    static let atomicScale = 9
    static let sessionCacheTTL: TimeInterval = 150

    let apiOperationFactory: BittensorApiOperationFactoryProtocol

    private let callbackQueue = DispatchQueue(label: "com.novawallet.subtensor.catalogue.\(UUID().uuidString)")

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory

        super.init(operationQueue: operationQueue, cacheTTL: Self.sessionCacheTTL, logger: logger)
    }

    override func createFetchWrapper() -> CompoundOperationWrapper<SubtensorSubnetCatalogue> {
        let responseWrapper = apiOperationFactory.createSubnetsWrapper()
        let logger = logger

        let catalogueOperation = ClosureOperation<SubtensorSubnetCatalogue> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeCatalogue(from: response, logger: logger)
        }

        catalogueOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: catalogueOperation)
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

            let subnet = try makeSubnet(item, path: "items[\(index)]", stamps: stamps, requestId: response.requestId)
            subnets.append(subnet)
        }

        return SubtensorSubnetCatalogue(subnets: subnets)
    }

    static func makeSubnet(
        _ item: BittensorApi.Subnet,
        path: String,
        stamps: Stamps,
        requestId: String?
    ) throws -> SubtensorCatalogueSubnet {
        try SubtensorCatalogueSubnet(
            netuid: item.netuid,
            name: item.name,
            symbol: item.symbol,
            networkRegisteredAt: item.networkRegisteredAt,
            tempo: item.tempo,
            ownerColdkey: item.ownerColdkey,
            ownerHotkey: item.ownerHotkey,
            links: SubtensorSubnetLinks(
                githubRepo: item.githubRepo,
                subnetContact: item.subnetContact,
                subnetUrl: item.subnetUrl,
                subnetWebsite: item.subnetWebsite,
                discord: item.discord,
                additional: item.additional
            ),
            taoReserve: amount(item.taoReserve, field: "\(path).taoReserve", requestId: requestId),
            alphaReserve: amount(item.alphaReserve, field: "\(path).alphaReserve", requestId: requestId),
            alphaOutstanding: amount(item.alphaOutstanding, field: "\(path).alphaOutstanding", requestId: requestId),
            taoPerAlpha: amount(item.taoPerAlpha, field: "\(path).taoPerAlpha", requestId: requestId),
            metadataStamp: stamps.metadata,
            pricesStamp: stamps.prices
        )
    }

    static func amount(_ value: String, field: String, requestId: String?) throws -> Balance {
        do {
            return try BittensorApiDecimal.atomic(value, scale: atomicScale)
        } catch {
            throw BittensorApiError.contractViolation(detail: "GET /subnets: invalid \(field)", requestId: requestId)
        }
    }
}

extension SubtensorSubnetCatalogueService: SubtensorSubnetCatalogueServiceProtocol {
    func createCatalogueWrapper(forcingRefresh: Bool) -> CompoundOperationWrapper<SubtensorSubnetCatalogue> {
        let callbackQueue = callbackQueue

        let catalogueOperation = AsyncClosureOperation<SubtensorSubnetCatalogue> { completion in
            self.fetch(forcingRefresh: forcingRefresh, runningCompletionIn: callbackQueue, completion: completion)
        }

        return CompoundOperationWrapper(targetOperation: catalogueOperation)
    }
}
