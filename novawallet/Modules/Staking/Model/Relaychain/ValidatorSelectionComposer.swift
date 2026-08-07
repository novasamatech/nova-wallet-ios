import Foundation

struct ValidatorSelectionComposer {
    let lockedValidators: [SelectedValidatorInfo]
    let maxNominations: Int

    func compose(from initialTargets: [SelectedValidatorInfo]) -> [SelectedValidatorInfo] {
        initialTargets
            .sorted { $0.stakeReturn > $1.stakeReturn }
            .reservingSlots(for: lockedValidators, limit: maxNominations)
    }
}
