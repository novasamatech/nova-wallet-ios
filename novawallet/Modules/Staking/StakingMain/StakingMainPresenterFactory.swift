import Foundation
import SoraKeystore
import SoraFoundation

protocol StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol?
}

final class StakingMainPresenterFactory {
    let applicationHandler: ApplicationHandlerProtocol

    init(applicationHandler: ApplicationHandlerProtocol) {
        self.applicationHandler = applicationHandler
    }
}

extension StakingMainPresenterFactory: StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        let stakingType = stakingAssetSettings.value?.asset.stakings?.first

        switch stakingType {
        case .relaychain:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view, consensus: .babe)
        case .auraRelaychain:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view, consensus: .aura)
        case .parachain, .turing:
            return createParachainPresenter(for: stakingAssetSettings, view: view)
        case .azero:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view, consensus: .aura)
        case .unsupported, .none:
            return nil
        }
    }
}
