import Foundation
import Operation_iOS

enum SubtensorValidatorDirectoryServiceError: Error {
    case rootMetagraphUnavailable
}

final class SubtensorValidatorDirectoryService {
    static let enrichmentRowLimit = 512

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let cache: SubtensorValidatorDirectoryCaching
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol,
        cache: SubtensorValidatorDirectoryCaching,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.cache = cache
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorDirectoryService {
    struct CachedItem {
        let item: SubtensorValidatorDirectoryItem
        let isEnriched: Bool
    }

    func store(
        _ directory: SubtensorValidatorDirectory,
        listingReceipt: ListingReceipt,
        enrichedPairs: Set<SubtensorHotkeySubnet>
    ) {
        cache.store(
            SubtensorValidatorDirectoryCacheEntry(
                directory: directory,
                listingReceipt: listingReceipt,
                items: Dictionary(directory.items.map { ($0.hotkey, $0) }, uniquingKeysWith: { first, _ in first }),
                enrichedHotkeys: Set(enrichedPairs.map(\.hotkey))
            )
        )
    }

    func peek(
        _ cached: SubtensorValidatorDirectoryCacheEntry,
        netuid: UInt16
    ) -> HTTPCachePeek<SubtensorValidatorDirectory> {
        guard
            case let .fresh(response, freshUntil) = apiOperationFactory.peekValidators(netuid: netuid),
            ListingReceipt(response: response) == cached.listingReceipt else {
            return .expired(cached.directory.markingStale())
        }

        return .fresh(cached.directory, freshUntil: freshUntil)
    }

    func cachedItem(for hotkey: AccountId, subnet: SubtensorSubnetRef) -> CachedItem? {
        guard let cached = cache.entry(for: subnet), let item = cached.items[hotkey] else {
            return nil
        }

        let hasFreshStakes = peek(cached, netuid: subnet.netuid).value?.listStamp?.freshness == .fresh

        return CachedItem(
            item: hasFreshStakes ? item : item.withoutReportedStake(),
            isEnriched: cached.enrichedHotkeys.contains(hotkey)
        )
    }

    func createListingWrapper(for netuid: UInt16) -> CompoundOperationWrapper<Listing> {
        let validatorsWrapper = apiOperationFactory.createValidatorsWrapper(netuid: netuid)
        let logger = logger

        let listingOperation = ClosureOperation<Listing> {
            let response = try validatorsWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeListing(from: response, netuid: netuid, logger: logger)
        }

        listingOperation.addDependency(validatorsWrapper.targetOperation)

        return validatorsWrapper.insertingTail(operation: listingOperation)
    }

    func createSnapshotWrapper(
        dependingOn queryOperation: BaseOperation<SubtensorValidatorChainQuery>
    ) -> CompoundOperationWrapper<SubtensorValidatorChainSnapshot> {
        let chainOperationFactory = chainOperationFactory

        let snapshotWrapper: CompoundOperationWrapper<SubtensorValidatorChainSnapshot> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let query = try queryOperation.extractNoCancellableResultData()

                return chainOperationFactory.createChainSnapshotWrapper(for: query)
            }

        snapshotWrapper.addDependency(operations: [queryOperation])

        return snapshotWrapper
    }

    func createChainItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef,
        name: String?,
        stake: BigRational?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
        let pair = SubtensorHotkeySubnet(hotkey: hotkey, netuid: subnet.netuid)
        let query = SubtensorValidatorChainQuery(pairs: [pair], includesHotkeyAlpha: true)
        let snapshotWrapper = chainOperationFactory.createChainSnapshotWrapper(for: query)

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem> {
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let enrichment = Enrichment(snapshot: snapshot, enrichedPairs: [pair])

            return Self.makeItem(
                hotkey: hotkey,
                name: name,
                stake: stake,
                netuid: subnet.netuid,
                enrichment: enrichment
            )
        }

        itemOperation.addDependency(snapshotWrapper.targetOperation)

        return snapshotWrapper.insertingTail(operation: itemOperation)
    }
}

extension SubtensorValidatorDirectoryService: SubtensorValidatorDirectoryServiceProtocol {
    func createDirectoryWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectory> {
        let listingWrapper = createListingWrapper(for: subnet.netuid)

        let queryOperation = ClosureOperation<SubtensorValidatorChainQuery> {
            let rows = try listingWrapper.targetOperation.extractNoCancellableResultData().rows

            return Self.enrichmentQuery(rows: rows, netuid: subnet.netuid)
        }

        queryOperation.addDependency(listingWrapper.targetOperation)

        let snapshotWrapper = createSnapshotWrapper(dependingOn: queryOperation)

        let directoryOperation = ClosureOperation<SubtensorValidatorDirectory> { [weak self] in
            let listing = try listingWrapper.targetOperation.extractNoCancellableResultData()
            let enrichedPairs = try Set(queryOperation.extractNoCancellableResultData().pairs)
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let enrichment = Enrichment(snapshot: snapshot, enrichedPairs: enrichedPairs)

            let directory = Self.makeDirectory(subnet: subnet, listing: listing, enrichment: enrichment)

            self?.store(directory, listingReceipt: listing.receipt, enrichedPairs: enrichedPairs)

            return directory
        }

        directoryOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: directoryOperation,
            dependencies: listingWrapper.allOperations + [queryOperation] + snapshotWrapper.allOperations
        )
    }

    func cachedDirectory(for subnet: SubtensorSubnetRef) -> HTTPCachePeek<SubtensorValidatorDirectory> {
        guard let cached = cache.entry(for: subnet) else {
            return .miss
        }

        return peek(cached, netuid: subnet.netuid)
    }

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDetail> {
        let identitiesWrapper = chainOperationFactory.createIdentitiesWrapper(for: [hotkey])
        let logger = logger

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                let cached = cachedItem(for: hotkey, subnet: subnet)

                if let cached, cached.isEnriched {
                    return .createWithResult(cached.item)
                }

                return createChainItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    name: cached?.item.name,
                    stake: cached?.item.reportedStake
                )
            }

        let detailOperation = ClosureOperation<SubtensorValidatorDetail> {
            let item = try itemWrapper.targetOperation.extractNoCancellableResultData()

            do {
                let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()

                return SubtensorValidatorDetail(item: item, identity: identities[hotkey])
            } catch {
                logger.warning("Subtensor validator identity unavailable: \(error)")

                return SubtensorValidatorDetail(item: item, identity: nil)
            }
        }

        detailOperation.addDependency(itemWrapper.targetOperation)
        detailOperation.addDependency(identitiesWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: detailOperation,
            dependencies: identitiesWrapper.allOperations + itemWrapper.allOperations
        )
    }
}
