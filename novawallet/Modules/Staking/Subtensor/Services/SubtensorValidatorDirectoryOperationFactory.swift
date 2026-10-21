import Foundation
import Operation_iOS

final class SubtensorValidatorDirectoryOperationFactory {
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

private extension SubtensorValidatorDirectoryOperationFactory {
    func createListedItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef,
        requiresListing: Bool
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let directoryWrapper = createDirectoryWrapper(for: subnet)

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            let directory: SubtensorValidatorDirectory?

            if requiresListing {
                directory = try directoryWrapper.targetOperation.extractNoCancellableResultData()
            } else {
                directory = try? directoryWrapper.targetOperation.extractNoCancellableResultData()
            }

            guard let directory, var item = directory.items.first(where: { $0.hotkey == hotkey }) else {
                return nil
            }

            if directory.listStamp?.freshness != .fresh {
                item.reportedStake = nil
            }

            return item
        }

        itemOperation.addDependency(directoryWrapper.targetOperation)

        return directoryWrapper.insertingTail(operation: itemOperation)
    }

    func createChainItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef,
        name: String?,
        stake: BigRational?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
        let pair = SubtensorHotkeySubnet(hotkey: hotkey, netuid: subnet.netuid)
        let query = SubtensorValidatorChainQuery(pairs: [pair])
        return chainOperationFactory.createChainSnapshotWrapper(for: query).mapped { snapshot in
            SubtensorValidatorDirectoryItem(
                hotkey: hotkey,
                netuid: subnet.netuid,
                name: name,
                take: snapshot.takeFractions[hotkey],
                reportedStake: stake,
                status: SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair)
            )
        }
    }
}

extension SubtensorValidatorDirectoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol {
    func createDirectoryWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectory> {
        let logger = logger

        guard subnet.netuid != SubtensorPallet.rootNetuid else {
            return apiOperationFactory.createRootValidatorsWrapper().mapped { response in
                Self.makeRootListing(from: response, subnet: subnet, logger: logger)
            }
        }

        return apiOperationFactory.createValidatorsWrapper(netuid: subnet.netuid).mapped { response in
            Self.makeListing(from: response, subnet: subnet, logger: logger)
        }
    }

    func cachedDirectory(for subnet: SubtensorSubnetRef) -> HTTPCachePeek<SubtensorValidatorDirectory> {
        let logger = logger

        guard subnet.netuid != SubtensorPallet.rootNetuid else {
            return apiOperationFactory.peekRootValidators().map {
                Self.makeRootListing(from: $0, subnet: subnet, logger: logger)
            }
        }

        return apiOperationFactory.peekValidators(netuid: subnet.netuid).map {
            Self.makeListing(from: $0, subnet: subnet, logger: logger)
        }
    }

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem> {
        let listedWrapper = createListedItemWrapper(for: hotkey, subnet: subnet, requiresListing: false)

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
                    stake: listed?.reportedStake
                )
            }

        itemWrapper.addDependency(wrapper: listedWrapper)

        return itemWrapper.insertingHead(operations: listedWrapper.allOperations)
    }

    func createListedDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let listedWrapper = createListedItemWrapper(for: hotkey, subnet: subnet, requiresListing: true)
        let logger = logger

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                guard let listed = try listedWrapper.targetOperation.extractNoCancellableResultData() else {
                    return .createWithResult(nil)
                }

                let chainWrapper = createChainItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    name: listed.name,
                    stake: listed.reportedStake
                )

                let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
                    do {
                        return try chainWrapper.targetOperation.extractNoCancellableResultData()
                    } catch {
                        logger.warning("Subtensor validator chain detail unavailable, keeping the listing: \(error)")

                        var item = listed
                        item.isChainDetailUnavailable = true

                        return item
                    }
                }

                itemOperation.addDependency(chainWrapper.targetOperation)

                return chainWrapper.insertingTail(operation: itemOperation)
            }

        itemWrapper.addDependency(wrapper: listedWrapper)

        return itemWrapper.insertingHead(operations: listedWrapper.allOperations)
    }

    func createListedDetailsWrapper(
        for hotkeys: [AccountId],
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<[AccountId: SubtensorValidatorDirectoryItem]> {
        let directoryWrapper = createDirectoryWrapper(for: subnet)
        let logger = logger

        let itemsWrapper: CompoundOperationWrapper<[AccountId: SubtensorValidatorDirectoryItem]> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                let directory = try directoryWrapper.targetOperation.extractNoCancellableResultData()
                let listed = Self.listedItems(for: hotkeys, in: directory)

                guard !listed.isEmpty else {
                    return .createWithResult([:])
                }

                let pairs = listed.keys.map { SubtensorHotkeySubnet(hotkey: $0, netuid: subnet.netuid) }
                let chainWrapper = chainOperationFactory.createChainSnapshotWrapper(
                    for: SubtensorValidatorChainQuery(pairs: pairs)
                )

                let itemsOperation = ClosureOperation<[AccountId: SubtensorValidatorDirectoryItem]> {
                    do {
                        let snapshot = try chainWrapper.targetOperation.extractNoCancellableResultData()

                        return pairs.reduce(into: listed) { items, pair in
                            items[pair.hotkey]?.take = snapshot.takeFractions[pair.hotkey]
                            items[pair.hotkey]?.status = SubtensorValidatorChainStatus.make(
                                snapshot: snapshot,
                                pair: pair
                            )
                        }
                    } catch {
                        logger.warning("Subtensor validators chain detail unavailable, keeping the listing: \(error)")

                        return listed.mapValues { item in
                            var item = item
                            item.isChainDetailUnavailable = true
                            return item
                        }
                    }
                }

                itemsOperation.addDependency(chainWrapper.targetOperation)

                return chainWrapper.insertingTail(operation: itemsOperation)
            }

        itemsWrapper.addDependency(wrapper: directoryWrapper)

        return itemsWrapper.insertingHead(operations: directoryWrapper.allOperations)
    }
}

private extension SubtensorValidatorDirectoryOperationFactory {
    static func listedItems(
        for hotkeys: [AccountId],
        in directory: SubtensorValidatorDirectory
    ) -> [AccountId: SubtensorValidatorDirectoryItem] {
        let requested = Set(hotkeys)
        let isFresh = directory.listStamp?.freshness == .fresh

        return directory.items.reduce(into: [:]) { items, item in
            guard requested.contains(item.hotkey), items[item.hotkey] == nil else {
                return
            }

            var listed = item

            if !isFresh {
                listed.reportedStake = nil
            }

            items[item.hotkey] = listed
        }
    }
}
