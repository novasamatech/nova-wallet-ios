import Foundation
import SoraKeystore

protocol StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol?
}

final class StakingMainPresenterFactory {}

extension StakingMainPresenterFactory: StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        let stakingType = StakingType(rawType: stakingAssetSettings.value?.asset.staking)

        switch stakingType {
        case .relaychain:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view, consensus: .babe)
        case .parachain:
            return createParachainPresenter(for: stakingAssetSettings, view: view)
        case .azero:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view, consensus: .aura)
        case .unsupported:
            return nil
        }
    }
}
