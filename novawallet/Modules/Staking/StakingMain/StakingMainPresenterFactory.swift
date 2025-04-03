import Foundation
import Keystore_iOS
import Foundation_iOS

protocol StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol?
}

final class StakingMainPresenterFactory {
    let applicationHandler: ApplicationHandlerProtocol
    let sharedStateFactory: StakingSharedStateFactoryProtocol

    init(applicationHandler: ApplicationHandlerProtocol, sharedStateFactory: StakingSharedStateFactoryProtocol) {
        self.applicationHandler = applicationHandler
        self.sharedStateFactory = sharedStateFactory
    }
}

extension StakingMainPresenterFactory: StakingMainPresenterFactoryProtocol {
    func createPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingMainChildPresenterProtocol? {
        switch stakingOption.type {
        case .relaychain, .auraRelaychain, .azero:
            return createRelaychainPresenter(for: stakingOption, view: view)
        case .parachain, .turing:
            return createParachainPresenter(for: stakingOption, view: view)
        case .nominationPools:
            return createNominationPoolsPresenter(for: stakingOption.chainAsset, view: view)
        case .mythos:
            return createMythosPresenter(for: stakingOption, view: view)
        case .unsupported:
            return nil
        }
    }
}
