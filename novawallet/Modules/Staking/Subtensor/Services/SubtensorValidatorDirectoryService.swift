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
    func createListedItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let directoryWrapper = createDirectoryWrapper(for: subnet)

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            guard
                let directory = try? directoryWrapper.targetOperation.extractNoCancellableResultData(),
                var item = directory.items.first(where: { $0.hotkey == hotkey }) else {
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

extension SubtensorValidatorDirectoryService: SubtensorValidatorDirectoryServiceProtocol {
    func createDirectoryWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectory> {
        let logger = logger

        guard subnet.netuid != SubtensorStakingPallet.rootNetuid else {
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

        guard subnet.netuid != SubtensorStakingPallet.rootNetuid else {
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
        let listedWrapper = createListedItemWrapper(for: hotkey, subnet: subnet)

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
}
