import Foundation
import Operation_iOS

final class SubtensorValidatorDirectoryService {
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorDirectoryService {
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

    func cachedListing(for netuid: UInt16) -> HTTPCachePeek<Listing> {
        let logger = logger

        guard netuid != SubtensorStakingPallet.rootNetuid else {
            return apiOperationFactory.peekRootValidators().map { Self.makeRootListing(from: $0, logger: logger) }
        }

        return apiOperationFactory.peekValidators(netuid: netuid).map {
            Self.makeListing(from: $0, netuid: netuid, logger: logger)
        }
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

            return SubtensorValidatorDirectoryItem(
                hotkey: hotkey,
                netuid: subnet.netuid,
                name: name,
                take: snapshot.takeFractions[hotkey],
                reportedStake: stake,
                status: SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair)
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

        let directoryOperation = ClosureOperation<SubtensorValidatorDirectory> {
            let listing = try listingWrapper.targetOperation.extractNoCancellableResultData()

            return Self.makeDirectory(subnet: subnet, listing: listing)
        }

        directoryOperation.addDependency(listingWrapper.targetOperation)

        return listingWrapper.insertingTail(operation: directoryOperation)
    }

    func cachedDirectory(for subnet: SubtensorSubnetRef) -> HTTPCachePeek<SubtensorValidatorDirectory> {
        cachedListing(for: subnet.netuid).map { Self.makeDirectory(subnet: subnet, listing: $0) }
    }

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
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

        return itemWrapper.insertingHead(operations: listedWrapper.allOperations)
    }
}
