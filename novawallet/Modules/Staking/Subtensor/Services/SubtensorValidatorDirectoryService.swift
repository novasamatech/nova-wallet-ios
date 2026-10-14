import Foundation
import Operation_iOS

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
        apiOperationFactory.addContextObserver(cache) { [weak cache] in cache?.invalidate() }
    }
}

private extension SubtensorValidatorDirectoryService {
    func store(_ directory: SubtensorValidatorDirectory, generation: UUID) throws {
        try cache.store(
            SubtensorValidatorDirectoryCacheEntry(
                directory: directory,
                items: Dictionary(directory.items.map { ($0.hotkey, $0) }, uniquingKeysWith: { first, _ in first })
            ),
            generation: generation
        )
    }

    func createListedRowWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<Row?> {
        let listingWrapper = createListingWrapper(for: subnet.netuid)

        let rowOperation = ClosureOperation<Row?> {
            guard
                let listing = try? listingWrapper.targetOperation.extractNoCancellableResultData(),
                let row = listing.rows.first(where: { $0.hotkey == hotkey }) else {
                return nil
            }

            return Row(
                hotkey: row.hotkey,
                name: row.name,
                stake: listing.listStamp?.freshness == .fresh ? row.stake : nil
            )
        }

        rowOperation.addDependency(listingWrapper.targetOperation)

        return listingWrapper.insertingTail(operation: rowOperation)
    }

    func createListingWrapper(for netuid: UInt16) -> CompoundOperationWrapper<Listing> {
        let logger = logger

        guard netuid != SubtensorStakingPallet.rootNetuid else {
            let rootWrapper = apiOperationFactory.createRootValidatorsWrapper()

            let listingOperation = ClosureOperation<Listing> {
                let response = try rootWrapper.targetOperation.extractNoCancellableResultData()

                return Self.makeRootListing(from: response, logger: logger)
            }

            listingOperation.addDependency(rootWrapper.targetOperation)

            return rootWrapper.insertingTail(operation: listingOperation)
        }

        let validatorsWrapper = apiOperationFactory.createValidatorsWrapper(netuid: netuid)

        let listingOperation = ClosureOperation<Listing> {
            let response = try validatorsWrapper.targetOperation.extractNoCancellableResultData()

            return Self.makeListing(from: response, netuid: netuid, logger: logger)
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
        let query = SubtensorValidatorChainQuery(pairs: [pair])
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
        let generation = cache.generation
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

            guard let self else { throw BaseOperationError.parentOperationCancelled }
            try store(directory, generation: generation)

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

        return .expired(cached.directory.markingStale())
    }

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
        let cache = cache
        let generation = cache.generation
        let listedWrapper = createListedRowWrapper(for: hotkey, subnet: subnet)

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                let listed = try listedWrapper.targetOperation.extractNoCancellableResultData()

                return createChainItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    name: listed?.name,
                    stake: listed?.stake
                )
            }

        itemWrapper.addDependency(wrapper: listedWrapper)

        let detailOperation = ClosureOperation<SubtensorValidatorDirectoryItem> {
            let item = try itemWrapper.targetOperation.extractNoCancellableResultData()

            guard generation == cache.generation else {
                throw BittensorApiError.attestationUnavailable(requestId: nil)
            }

            return item
        }

        detailOperation.addDependency(itemWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: detailOperation,
            dependencies: listedWrapper.allOperations + itemWrapper.allOperations
        )
    }
}
