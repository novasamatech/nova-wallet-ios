import Foundation
import SoraKeystore
import SoraFoundation

protocol StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
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
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        switch stakingOption.type {
        case .relaychain:
            return createRelaychainPresenter(for: stakingOption, view: view, consensus: .babe)
        case .auraRelaychain:
            return createRelaychainPresenter(for: stakingOption, view: view, consensus: .aura)
        case .parachain, .turing:
            return createParachainPresenter(for: stakingOption, view: view)
        case .azero:
            return createRelaychainPresenter(for: stakingOption, view: view, consensus: .aura)
        case .unsupported:
            return nil
        }
    }
}
