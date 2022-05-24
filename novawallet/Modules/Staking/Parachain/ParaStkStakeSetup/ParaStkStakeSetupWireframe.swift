import Foundation

final class ParaStkStakeSetupWireframe: ParaStkStakeSetupWireframeProtocol {
    let state: ParachainStakingSharedState

    init(state: ParachainStakingSharedState) {
        self.state = state
    }

    func showConfirmation(
        from _: ParaStkStakeSetupViewProtocol?,
        collator _: DisplayAddress,
        amount _: Decimal
    ) {}
}
