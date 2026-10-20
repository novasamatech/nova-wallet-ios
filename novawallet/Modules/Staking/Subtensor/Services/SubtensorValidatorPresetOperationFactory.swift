import Foundation
import Operation_iOS

protocol SubtensorValidatorPresetOperationFactoryProtocol {
    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>

    func createListedPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>

    func createLockedWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>
}

final class SubtensorValidatorPresetOperationFactory {
    let directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol
    let recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol,
        recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol,
        yieldOperationFactory: SubtensorYieldOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.directoryOperationFactory = directoryOperationFactory
        self.recommendationOperationFactory = recommendationOperationFactory
        self.yieldOperationFactory = yieldOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorPresetOperationFactory {
    static func highestYield(
        among validators: [SubtensorRecommendedValidator],
        yields: SubtensorAlphaYields?
    ) -> SubtensorRecommendedValidator? {
        let rate: (SubtensorRecommendedValidator) -> Decimal? = { yields?.yields[$0.hotkey]?.annualRate }
        let maxRate = validators.compactMap(rate).max()

        return validators.first { rate($0) == maxRate }
    }

    func createRecommendedWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let recommendedWrapper = recommendationOperationFactory.createRecommendedValidatorsWrapper(for: subnet)
        let yieldOperationFactory = yieldOperationFactory
        let yieldsWrapper = yieldOperationFactory.createAlphaYieldsWrapper(for: subnet.netuid)

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                let recommended = try recommendedWrapper.targetOperation.extractNoCancellableResultData()
                let yields = (try? yieldsWrapper.targetOperation.extractNoCancellableResultData()) ??
                    yieldOperationFactory.cachedAlphaYields(for: subnet.netuid).value

                return self?.createBestItemWrapper(
                    among: recommended.validators,
                    yields: yields,
                    subnet: subnet,
                    allowsFallback: true
                )
            }

        presetWrapper.addDependency(wrapper: recommendedWrapper)
        presetWrapper.addDependency(wrapper: yieldsWrapper)

        return presetWrapper.insertingHead(operations: recommendedWrapper.allOperations + yieldsWrapper.allOperations)
    }

    func createBestItemWrapper(
        among validators: [SubtensorRecommendedValidator],
        yields: SubtensorAlphaYields?,
        subnet: SubtensorSubnetRef,
        allowsFallback: Bool
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        guard let winner = Self.highestYield(among: validators, yields: yields) else {
            return .createWithResult(nil)
        }

        let itemWrapper = createItemWrapper(for: winner.hotkey, subnet: subnet)

        let bestWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                let item = try itemWrapper.targetOperation.extractNoCancellableResultData()

                if let item, !item.isInactive {
                    return .createWithResult(item.named(item.name ?? winner.name))
                }

                guard allowsFallback else {
                    return nil
                }

                return self?.createBestItemWrapper(
                    among: validators.filter { $0.hotkey != winner.hotkey },
                    yields: yields,
                    subnet: subnet,
                    allowsFallback: false
                )
            }

        bestWrapper.addDependency(wrapper: itemWrapper)

        return bestWrapper.insertingHead(operations: itemWrapper.allOperations)
    }

    func createItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let detailWrapper = directoryOperationFactory.createDetailWrapper(for: hotkey, subnet: subnet)
        let logger = logger

        let itemOperation = ClosureOperation<SubtensorValidatorDirectoryItem?> {
            do {
                return try detailWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.warning("Subtensor validator detail unavailable for the preset: \(error)")

                return nil
            }
        }

        itemOperation.addDependency(detailWrapper.targetOperation)

        return detailWrapper.insertingTail(operation: itemOperation)
    }

    func createListedItemWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        let listedWrapper = directoryOperationFactory.createListedDetailWrapper(for: hotkey, subnet: subnet)

        let itemWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                if let listed = try listedWrapper.targetOperation.extractNoCancellableResultData() {
                    return .createWithResult(listed)
                }

                return self?.createItemWrapper(for: hotkey, subnet: subnet)
            }

        itemWrapper.addDependency(wrapper: listedWrapper)

        return itemWrapper.insertingHead(operations: listedWrapper.allOperations)
    }

    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        guard let existingWrapper else {
            return createRecommendedWrapper(for: subnet)
        }

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                let existing = try existingWrapper.targetOperation.extractNoCancellableResultData()

                if let existing, !existing.isInactive {
                    return .createWithResult(existing)
                }

                return self?.createRecommendedWrapper(for: subnet)
            }

        presetWrapper.addDependency(wrapper: existingWrapper)

        return presetWrapper.insertingHead(operations: existingWrapper.allOperations)
    }
}

extension SubtensorValidatorPresetOperationFactory: SubtensorValidatorPresetOperationFactoryProtocol {
    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        createPresetWrapper(
            for: subnet,
            existingWrapper: existingHotkey.map { createItemWrapper(for: $0, subnet: subnet) }
        )
    }

    func createListedPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        createPresetWrapper(
            for: subnet,
            existingWrapper: existingHotkey.map { createListedItemWrapper(for: $0, subnet: subnet) }
        )
    }

    func createLockedWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        createItemWrapper(for: hotkey, subnet: subnet)
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
