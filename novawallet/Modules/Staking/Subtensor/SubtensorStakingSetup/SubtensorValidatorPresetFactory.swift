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
    let yieldService: SubtensorYieldServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.directoryService = directoryService
        self.recommendationService = recommendationService
        self.yieldService = yieldService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorValidatorPresetFactory {
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
        let recommendedWrapper = recommendationService.createRecommendedValidatorsWrapper(for: subnet)
        let yieldsWrapper = yieldService.createAlphaYieldsWrapper(for: subnet.netuid)

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                let recommended = try recommendedWrapper.targetOperation.extractNoCancellableResultData()

                return self?.createBestItemWrapper(
                    among: recommended.validators,
                    yields: try? yieldsWrapper.targetOperation.extractNoCancellableResultData(),
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
                if let item = try itemWrapper.targetOperation.extractNoCancellableResultData() {
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
        let detailWrapper = directoryService.createDetailWrapper(for: hotkey, subnet: subnet)
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
}

extension SubtensorValidatorPresetFactory: SubtensorValidatorPresetFactoryProtocol {
    func createPresetWrapper(
        for subnet: SubtensorSubnetRef,
        existingHotkey: AccountId?
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> {
        guard let existingHotkey else {
            return createRecommendedWrapper(for: subnet)
        }

        let existingWrapper = createItemWrapper(for: existingHotkey, subnet: subnet)

        let presetWrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?> =
            OperationCombiningService.compoundOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                if let existing = try existingWrapper.targetOperation.extractNoCancellableResultData() {
                    return .createWithResult(existing)
                }

                return self?.createRecommendedWrapper(for: subnet)
            }

        presetWrapper.addDependency(wrapper: existingWrapper)

        return presetWrapper.insertingHead(operations: existingWrapper.allOperations)
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
