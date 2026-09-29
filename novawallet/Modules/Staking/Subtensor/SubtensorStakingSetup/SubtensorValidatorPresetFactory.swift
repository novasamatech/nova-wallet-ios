import Foundation
import Operation_iOS

protocol SubtensorValidatorPresetFactoryProtocol {
    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>

    func createLockedWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>
}

final class SubtensorValidatorPresetFactory {
    let directoryService: SubtensorValidatorDirectoryServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.directoryService = directoryService
        self.recommendationService = recommendationService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorPresetFactory {
    func createNamesWrapper(for subnet: SubtensorSubnetRef) -> CompoundOperationWrapper<[AccountId: String]> {
        let directoryWrapper = directoryService.createDirectoryWrapper(for: subnet)
        let logger = logger

        let namesOperation = ClosureOperation<[AccountId: String]> {
            do {
                let directory = try directoryWrapper.targetOperation.extractNoCancellableResultData()

                return directory.items.reduce(into: [AccountId: String]()) { names, item in
                    if let name = item.name {
                        names[item.hotkey] = name
                    }
                }
            } catch {
                logger.warning("Subtensor validator names unavailable for the preset: \(error)")

                return [:]
            }
        }

        namesOperation.addDependency(directoryWrapper.targetOperation)

        return directoryWrapper.insertingTail(operation: namesOperation)
    }

    func createDetailWrapper(
        for hotkey: AccountId?,
        subnet: SubtensorSubnetRef,
        dependingOn namesWrapper: CompoundOperationWrapper<[AccountId: String]>
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let directoryService = directoryService
        let logger = logger

        let wrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                guard let hotkey else {
                    return nil
                }

                let detailWrapper = directoryService.createDetailWrapper(for: hotkey, subnet: subnet)

                let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
                    do {
                        return try detailWrapper.targetOperation.extractNoCancellableResultData().item
                    } catch {
                        logger.warning("Subtensor validator detail unavailable for the preset: \(error)")

                        return nil
                    }
                }

                itemOperation.addDependency(detailWrapper.targetOperation)

                return detailWrapper.insertingTail(operation: itemOperation)
            }

        wrapper.addDependency(wrapper: namesWrapper)

        return wrapper
    }

    static func createPreferredWrapper(
        for subnet: SubtensorSubnetRef,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let preferredWrapper = directoryService.createPreferredValidatorWrapper(for: subnet)

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            do {
                return try preferredWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Subtensor preferred validator unavailable for the preset: \(error)")

                return nil
            }
        }

        itemOperation.addDependency(preferredWrapper.targetOperation)

        return preferredWrapper.insertingTail(operation: itemOperation)
    }

    func createNamingOperation(
        namesWrapper: CompoundOperationWrapper<[AccountId: String]>,
        itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>
    ) -> BaseOperation<SubtensorValidatorDirectoryItem?> {
        let operation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            let names = try namesWrapper.targetOperation.extractNoCancellableResultData()

            guard let item = try itemWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            return item.named(item.name ?? names[item.hotkey])
        }

        operation.addDependency(namesWrapper.targetOperation)
        operation.addDependency(itemWrapper.targetOperation)

        return operation
    }

    static func isSelectable(
        _ item: SubtensorValidatorDirectoryItem?,
        on subnet: SubtensorSubnetRef,
        recommendationService: SubtensorRecommendationServiceProtocol
    ) -> Bool {
        guard let item else {
            return false
        }

        let gates = recommendationService.lastSeenClientGates() ?? .backendDefault

        return SubtensorValidatorListFactory.eligibility(
            of: item,
            isRoot: subnet.netuid == SubtensorStakingPallet.rootNetuid,
            maxTake: gates.maxTake
        ) == .selectable
    }
}

extension SubtensorValidatorPresetFactory: SubtensorValidatorPresetFactoryProtocol {
    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let namesWrapper = createNamesWrapper(for: subnet)
        let existingWrapper = createDetailWrapper(for: existingHotkey, subnet: subnet, dependingOn: namesWrapper)

        let directoryService = directoryService
        let recommendationService = recommendationService
        let logger = logger

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let existing = try existingWrapper.targetOperation.extractNoCancellableResultData()

                if Self.isSelectable(existing, on: subnet, recommendationService: recommendationService) {
                    return CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>.createWithResult(existing)
                }

                return Self.createPreferredWrapper(for: subnet, directoryService: directoryService, logger: logger)
            }

        presetWrapper.addDependency(wrapper: existingWrapper)

        let namingOperation = createNamingOperation(namesWrapper: namesWrapper, itemWrapper: presetWrapper)

        return CompoundOperationWrapper(
            targetOperation: namingOperation,
            dependencies: namesWrapper.allOperations + existingWrapper.allOperations + presetWrapper.allOperations
        )
    }

    func createLockedWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let namesWrapper = createNamesWrapper(for: subnet)
        let detailWrapper = createDetailWrapper(for: hotkey, subnet: subnet, dependingOn: namesWrapper)
        let namingOperation = createNamingOperation(namesWrapper: namesWrapper, itemWrapper: detailWrapper)

        return CompoundOperationWrapper(
            targetOperation: namingOperation,
            dependencies: namesWrapper.allOperations + detailWrapper.allOperations
        )
    }
}

extension SubtensorValidatorDirectoryItem {
    func named(_ newName: String?) -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: newName,
            take: take,
            reportedStake: reportedStake,
            status: status,
            isNovaPreferred: isNovaPreferred
        )
    }
}
