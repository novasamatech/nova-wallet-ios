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

private extension SubtensorVerifiedRecommendations {
    func presetHotkey(for subnet: SubtensorSubnetRef) -> AccountId? {
        guard
            generation.stamp.freshness == .fresh,
            subnet.registeredAt <= generation.sourceBlockNumber else {
            return nil
        }

        let pairs = [SubtensorRecommendationClass.stable, .balanced, .higherUpside].flatMap { classes[$0] ?? [] }

        return pairs.first { $0.netuid == subnet.netuid }?.hotkey
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

    func createGatesWrapper() -> CompoundOperationWrapper<SubtensorClientGates?> {
        let gatesWrapper = recommendationService.createClientGatesWrapper()
        let logger = logger

        let gatesOperation = ClosureOperation<SubtensorClientGates?> {
            do {
                return try gatesWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Subtensor client gates unavailable for the preset: \(error)")

                return nil
            }
        }

        gatesOperation.addDependency(gatesWrapper.targetOperation)

        return gatesWrapper.insertingTail(operation: gatesOperation)
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

                return Self.createItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    directoryService: directoryService,
                    logger: logger
                )
            }

        wrapper.addDependency(wrapper: namesWrapper)

        return wrapper
    }

    static func createItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
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

    static func createRecommendedWrapper(
        for subnet: SubtensorSubnetRef,
        recommendationService: SubtensorRecommendationServiceProtocol,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let recommendationsWrapper = recommendationService.createVerifiedRecommendationsWrapper()

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(operationManager: operationManager) {
                let recommendations: SubtensorVerifiedRecommendations

                do {
                    recommendations = try recommendationsWrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    logger.warning("Subtensor recommended validator unavailable for the preset: \(error)")

                    return nil
                }

                guard let hotkey = recommendations.presetHotkey(for: subnet) else {
                    return nil
                }

                return Self.createItemWrapper(
                    for: hotkey,
                    subnet: subnet,
                    directoryService: directoryService,
                    logger: logger
                )
            }

        itemWrapper.addDependency(wrapper: recommendationsWrapper)

        let selectableOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            let item = try itemWrapper.targetOperation.extractNoCancellableResultData()
            let gates = try? recommendationsWrapper.targetOperation.extractNoCancellableResultData().clientGates

            return Self.isSelectable(item, on: subnet, gates: gates) ? item : nil
        }

        selectableOperation.addDependency(recommendationsWrapper.targetOperation)
        selectableOperation.addDependency(itemWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: selectableOperation,
            dependencies: recommendationsWrapper.allOperations + itemWrapper.allOperations
        )
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
        gates: SubtensorClientGates?
    ) -> Bool {
        guard let item, let gates else {
            return false
        }

        return SubtensorValidatorListFactory.eligibility(
            of: item,
            isRoot: subnet.netuid == SubtensorStakingPallet.rootNetuid,
            gates: gates
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
        let gatesWrapper: CompoundOperationWrapper<SubtensorClientGates?> = existingHotkey != nil
            ? createGatesWrapper()
            : .createWithResult(nil)

        let directoryService = directoryService
        let recommendationService = recommendationService
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = logger

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(operationManager: operationManager) {
                let existing = try existingWrapper.targetOperation.extractNoCancellableResultData()
                let gates = try gatesWrapper.targetOperation.extractNoCancellableResultData()

                if Self.isSelectable(existing, on: subnet, gates: gates) {
                    return CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>.createWithResult(existing)
                }

                return Self.createRecommendedWrapper(
                    for: subnet,
                    recommendationService: recommendationService,
                    directoryService: directoryService,
                    operationManager: operationManager,
                    logger: logger
                )
            }

        presetWrapper.addDependency(wrapper: existingWrapper)
        presetWrapper.addDependency(wrapper: gatesWrapper)

        let namingOperation = createNamingOperation(namesWrapper: namesWrapper, itemWrapper: presetWrapper)

        return CompoundOperationWrapper(
            targetOperation: namingOperation,
            dependencies: namesWrapper.allOperations + existingWrapper.allOperations + gatesWrapper.allOperations +
                presetWrapper.allOperations
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
            status: status
        )
    }
}
