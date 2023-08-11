import Foundation
import SoraFoundation

final class StakingSelectPoolPresenter {
    weak var view: StakingSelectPoolViewProtocol?
    weak var delegate: StakingSelectPoolDelegate?

    let wireframe: StakingSelectPoolWireframeProtocol
    let interactor: StakingSelectPoolInteractorInputProtocol
    let viewModelFactory: StakingSelectPoolViewModelFactoryProtocol
    let chainAsset: ChainAsset

    private var poolStats: [NominationPools.PoolStats]?
    private var poolStatsMap: [NominationPools.PoolId: NominationPools.PoolStats] = [:]
    private var selectedPoolId: NominationPools.PoolId?
    private var recommendedPoolId: NominationPools.PoolId?

    init(
        interactor: StakingSelectPoolInteractorInputProtocol,
        wireframe: StakingSelectPoolWireframeProtocol,
        viewModelFactory: StakingSelectPoolViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        delegate: StakingSelectPoolDelegate?,
        selectedPool: NominationPools.SelectedPool?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.delegate = delegate
        selectedPoolId = selectedPool?.poolId
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        guard let stats = poolStats else {
            return
        }
        let viewModels = viewModelFactory.createStakingSelectPoolViewModels(
            from: stats,
            selectedPoolId: selectedPoolId,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceivePools(viewModels: viewModels)
    }

    private func provideSingleViewModel(poolId: NominationPools.PoolId?) {
        guard let poolId = poolId, let poolStats = poolStatsMap[poolId] else {
            return
        }
        let viewModel = viewModelFactory.createStakingSelectPoolViewModel(
            from: poolStats,
            selectedPoolId: selectedPoolId,
            chainAsset: chainAsset,
            locale: selectedLocale
        )

        view?.didReceivePoolUpdate(viewModel: viewModel)
    }

    private func sortPools() {
        guard let recommendedPoolId = recommendedPoolId,
              let poolStats = poolStats,
              let pool = poolStatsMap[recommendedPoolId] else {
            return
        }
        if poolStats[0].poolId != recommendedPoolId {
            if let currentPosition = poolStats.firstIndex(where: { $0.poolId == recommendedPoolId }) {
                self.poolStats?.remove(at: currentPosition)
                self.poolStats?.insert(poolStats[currentPosition], at: 0)
            }
        }
    }

    private func notifySelectedPoolChangedIfNeeded(oldSelection: NominationPools.PoolId?) {
        guard let selectedPoolId = selectedPoolId, oldSelection != selectedPoolId else {
            return
        }
        guard let poolStats = poolStatsMap[selectedPoolId] else {
            return
        }

        delegate?.changePoolSelection(selectedPool: .init(poolStats: poolStats))
    }
}

extension StakingSelectPoolPresenter: StakingSelectPoolPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectPool(poolId: NominationPools.PoolId) {
        guard let poolStats = poolStatsMap[poolId] else {
            return
        }
        let previousSelectedPoolId = selectedPoolId
        selectedPoolId = poolId
        provideSingleViewModel(poolId: previousSelectedPoolId)
        provideSingleViewModel(poolId: poolId)
        delegate?.changePoolSelection(selectedPool: .init(poolStats: poolStats))
        wireframe.complete(from: view)
    }

    func showPoolInfo(poolId: NominationPools.PoolId) {
        guard let view = view,
              let pool = poolStatsMap[poolId],
              let address = try? pool.bondedAccountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return
        }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }
}

extension StakingSelectPoolPresenter: StakingSelectPoolInteractorOutputProtocol {
    func didReceive(poolStats: [NominationPools.PoolStats]) {
        self.poolStats = poolStats
        poolStatsMap = poolStats.reduce(into: [NominationPools.PoolId: NominationPools.PoolStats]()) { result, pool in
            result[pool.poolId] = pool
        }
        notifySelectedPoolChangedIfNeeded(oldSelection: selectedPoolId)
        sortPools()
        provideViewModel()
    }

    func didReceive(recommendedPool: NominationPools.SelectedPool) {
        recommendedPoolId = recommendedPool.poolId
        if selectedPoolId == nil {
            selectedPoolId = recommendedPoolId
            notifySelectedPoolChangedIfNeeded(oldSelection: nil)
        }
        sortPools()
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
