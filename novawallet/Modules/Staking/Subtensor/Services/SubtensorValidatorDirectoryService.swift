import Foundation
import Operation_iOS

enum SubtensorValidatorDirectoryServiceError: Error {
    case rootMetagraphUnavailable
}

final class SubtensorValidatorDirectoryService {
    static let enrichmentRowLimit = 512

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var directories: [SubtensorSubnetRef: CachedDirectory] = [:]

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.earnConfigProvider = earnConfigProvider
        self.recommendationService = recommendationService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorDirectoryService {
    struct CachedDirectory {
        let chainBlock: BlockNumber
        let items: [AccountId: SubtensorValidatorDirectoryItem]
        let enrichedHotkeys: Set<AccountId>
    }

    struct CachedItem {
        let item: SubtensorValidatorDirectoryItem
        let isEnriched: Bool
    }

    func store(_ directory: SubtensorValidatorDirectory, enrichedPairs: Set<SubtensorHotkeySubnet>) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard (directories[directory.subnet]?.chainBlock ?? 0) <= directory.chainBlock else {
            return
        }

        directories[directory.subnet] = CachedDirectory(
            chainBlock: directory.chainBlock,
            items: Dictionary(directory.items.map { ($0.hotkey, $0) }, uniquingKeysWith: { first, _ in first }),
            enrichedHotkeys: Set(enrichedPairs.map(\.hotkey))
        )
    }

    func cachedItem(for hotkey: AccountId, subnet: SubtensorSubnetRef) -> CachedItem? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let cached = directories[subnet], let item = cached.items[hotkey] else {
            return nil
        }

        return CachedItem(item: item, isEnriched: cached.enrichedHotkeys.contains(hotkey))
    }

    func createPreferenceWrapper(for subnet: SubtensorSubnetRef) -> CompoundOperationWrapper<AccountId?> {
        let configWrapper = earnConfigProvider.createConfigWrapper()
        let logger = logger

        let preferenceOperation = ClosureOperation<AccountId?> {
            do {
                let config = try configWrapper.targetOperation.extractNoCancellableResultData()

                return Self.preferredHotkey(in: config, for: subnet)
            } catch {
                logger.warning("Subtensor Earn config unavailable for the preferred validator: \(error)")

                return nil
            }
        }

        preferenceOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: preferenceOperation)
    }

    func createListingWrapper(for netuid: UInt16) -> CompoundOperationWrapper<Listing> {
        let validatorsWrapper = apiOperationFactory.createValidatorsWrapper(netuid: netuid)
        let logger = logger

        let listingOperation = ClosureOperation<Listing> {
            let response = try validatorsWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeListing(from: response.value, netuid: netuid, logger: logger)
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
        preferredHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
        let pair = SubtensorHotkeySubnet(hotkey: hotkey, netuid: subnet.netuid)
        let query = SubtensorValidatorChainQuery(pairs: [pair], includesHotkeyAlpha: true)
        let snapshotWrapper = chainOperationFactory.createChainSnapshotWrapper(for: query)
        let recommendationService = recommendationService
        let logger = logger

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem> {
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let gatedPreference = Self.gatedPreference(
                preferredHotkey == hotkey ? hotkey : nil,
                netuid: subnet.netuid,
                snapshot: snapshot,
                recommendationService: recommendationService,
                logger: logger
            )

            let enrichment = Enrichment(snapshot: snapshot, enrichedPairs: [pair], gatedPreference: gatedPreference)

            return Self.makeItem(hotkey: hotkey, name: name, netuid: subnet.netuid, enrichment: enrichment)
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
        let preferenceWrapper = createPreferenceWrapper(for: subnet)

        let queryOperation = ClosureOperation<SubtensorValidatorChainQuery> {
            let rows = try listingWrapper.targetOperation.extractNoCancellableResultData().rows
            let preferredHotkey = try preferenceWrapper.targetOperation.extractNoCancellableResultData()

            return Self.enrichmentQuery(rows: rows, preferredHotkey: preferredHotkey, netuid: subnet.netuid)
        }

        queryOperation.addDependency(listingWrapper.targetOperation)
        queryOperation.addDependency(preferenceWrapper.targetOperation)

        let snapshotWrapper = createSnapshotWrapper(dependingOn: queryOperation)
        let recommendationService = recommendationService
        let logger = logger

        let directoryOperation = ClosureOperation<SubtensorValidatorDirectory> { [weak self] in
            let listing = try listingWrapper.targetOperation.extractNoCancellableResultData()
            let enrichedPairs = try Set(queryOperation.extractNoCancellableResultData().pairs)
            let preferredHotkey = try preferenceWrapper.targetOperation.extractNoCancellableResultData()
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let gatedPreference = Self.gatedPreference(
                preferredHotkey,
                netuid: subnet.netuid,
                snapshot: snapshot,
                recommendationService: recommendationService,
                logger: logger
            )

            let enrichment = Enrichment(
                snapshot: snapshot,
                enrichedPairs: enrichedPairs,
                gatedPreference: gatedPreference
            )

            let directory = Self.makeDirectory(subnet: subnet, listing: listing, enrichment: enrichment)

            self?.store(directory, enrichedPairs: enrichedPairs)

            return directory
        }

        directoryOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: directoryOperation,
            dependencies: listingWrapper.allOperations + preferenceWrapper.allOperations + [queryOperation] +
                snapshotWrapper.allOperations
        )
    }

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDetail> {
        let identitiesWrapper = chainOperationFactory.createIdentitiesWrapper(for: [hotkey])
        let preferenceWrapper = createPreferenceWrapper(for: subnet)
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

                return try createChainItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    name: cached?.item.name,
                    preferredHotkey: preferenceWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

        itemWrapper.addDependency(wrapper: preferenceWrapper)

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
            dependencies: identitiesWrapper.allOperations + preferenceWrapper.allOperations + itemWrapper.allOperations
        )
    }

    func createPreferredValidatorWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let preferenceWrapper = createPreferenceWrapper(for: subnet)

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                guard let hotkey = try preferenceWrapper.targetOperation.extractNoCancellableResultData() else {
                    return nil
                }

                return createChainItemWrapper(for: hotkey, subnet: subnet, name: nil, preferredHotkey: hotkey)
            }

        itemWrapper.addDependency(wrapper: preferenceWrapper)

        let gatedOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            let item = try itemWrapper.targetOperation.extractNoCancellableResultData()

            return item?.isNovaPreferred == true ? item : nil
        }

        gatedOperation.addDependency(itemWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: gatedOperation,
            dependencies: preferenceWrapper.allOperations + itemWrapper.allOperations
        )
    }
}
