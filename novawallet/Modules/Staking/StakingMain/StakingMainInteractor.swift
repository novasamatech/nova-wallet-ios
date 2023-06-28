import Foundation
import SoraKeystore
import RobinHood
import SubstrateSdk
import SoraFoundation

final class StakingMainInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingMainInteractorOutputProtocol?

    let commonSettings: SettingsManagerProtocol

    init(
        commonSettings: SettingsManagerProtocol
    ) {
        self.commonSettings = commonSettings
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveExpansion(commonSettings.stakingNetworkExpansion)
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }
}
