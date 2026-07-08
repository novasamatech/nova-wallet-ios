import Foundation
import UIKit
import Foundation_iOS

final class StartStakingInfoSubtensorWireframe: StartStakingInfoWireframe {
    let chainAsset: ChainAsset

    // Retained so the type-picker's onSelection closure (which weakly captures
    // the staking wireframe) can still reach a live wireframe when Continue is
    // tapped. Without this hold, the wireframe deallocates as soon as
    // showSetupAmount returns and Continue silently no-ops.
    private var stakingWireframe: SubtensorStakingWireframe?

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    override func showSetupAmount(from view: ControllerBackedProtocol?) {
        guard let viewController = view?.controller else { return }

        let wireframe = SubtensorStakingWireframe(
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared
        )
        stakingWireframe = wireframe
        wireframe.showStakingFlow(from: viewController)
    }
}
