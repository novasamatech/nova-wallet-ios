import Foundation
import SoraKeystore

protocol StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol?
}

final class StakingMainPresenterFactory {
    func createParachainPresenter(
        for _: StakingAssetSettings,
        view _: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        fatalError("Not implemented")
    }
}

extension StakingMainPresenterFactory: StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingAssetSettings: StakingAssetSettings,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        guard
            let stakingTypeString = stakingAssetSettings.value?.asset.staking,
            let stakingType = StakingType(rawValue: stakingTypeString) else {
            return nil
        }

        switch stakingType {
        case .relaychain:
            return createRelaychainPresenter(for: stakingAssetSettings, view: view)
        case .parachain:
            return createParachainPresenter(for: stakingAssetSettings, view: view)
        }
    }
}
