import Foundation
import SoraFoundation

final class StakingSelectPoolPresenter {
    weak var view: StakingSelectPoolViewProtocol?
    let wireframe: StakingSelectPoolWireframeProtocol
    let interactor: StakingSelectPoolInteractorInputProtocol
    let viewModelFactory: StakingSelectPoolViewModelFactoryProtocol
    let chainAsset: ChainAsset

    private var poolStats: [NominationPools.PoolStats]?

    init(
        interactor: StakingSelectPoolInteractorInputProtocol,
        wireframe: StakingSelectPoolWireframeProtocol,
        viewModelFactory: StakingSelectPoolViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard let stats = poolStats else {
            return
        }
        let viewModels = viewModelFactory.createStakingSelectPoolViewModels(
            from: stats,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceivePools(viewModels: viewModels)
    }
}

extension StakingSelectPoolPresenter: StakingSelectPoolPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectPool(poolId _: NominationPools.PoolId) {}

    func showPoolInfo(poolId _: NominationPools.PoolId) {}
}

extension StakingSelectPoolPresenter: StakingSelectPoolInteractorOutputProtocol {
    func didReceive(poolStats: [NominationPools.PoolStats]) {
        self.poolStats = poolStats
        provideViewModel()
    }
}

extension StakingSelectPoolPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}
