import Foundation
import Foundation_iOS
import Operation_iOS

final class NominationPoolSearchPresenter: AnyCancellableCleaning {
    weak var view: NominationPoolSearchViewProtocol?
    weak var delegate: StakingSelectPoolDelegate?

    let wireframe: NominationPoolSearchWireframeProtocol
    let interactor: NominationPoolSearchInteractorInputProtocol
    let viewModelFactory: StakingSelectPoolViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol
    let operationQueue: OperationQueue
    let dataValidatingFactory: NominationPoolDataValidatorFactoryProtocol
    let selectedPoolId: NominationPools.PoolId?

    private var poolStats: LoadableViewModelState<[NominationPools.PoolStats]> = .loaded(value: [])
    private var maxMembersPerPool: UInt32?

    init(
        interactor: NominationPoolSearchInteractorInputProtocol,
        wireframe: NominationPoolSearchWireframeProtocol,
        selectedPoolId: NominationPools.PoolId?,
        dataValidatingFactory: NominationPoolDataValidatorFactoryProtocol,
        viewModelFactory: StakingSelectPoolViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        delegate: StakingSelectPoolDelegate,
        operationQueue: OperationQueue,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedPoolId = selectedPoolId
        self.dataValidatingFactory = dataValidatingFactory
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.operationQueue = operationQueue
        self.delegate = delegate
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideVidewModel() {
        switch poolStats {
        case .loading:
            view?.didReceivePools(state: .loading)
        case let .cached(stats), let .loaded(stats):
            let viewModel = viewModelFactory.createStakingSelectPoolViewModels(
                from: stats,
                selectedPoolId: selectedPoolId,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceivePools(state: .loaded(viewModel: viewModel))
        }
    }
}

extension NominationPoolSearchPresenter: NominationPoolSearchPresenterProtocol {
    func setup() {
        interactor.setup()
        view?.didReceivePools(state: .loaded(viewModel: []))
    }

    func search(for textEntry: String) {
        interactor.search(for: textEntry)
    }

    func selectPool(poolId: NominationPools.PoolId) {
        let optPool = poolStats.value?.first(where: { $0.poolId == poolId })

        DataValidationRunner(validators: [
            dataValidatingFactory.selectedPoolIsOpen(for: optPool, locale: selectedLocale),
            dataValidatingFactory.selectedPoolIsNotFull(for: optPool, maxMembers: nil, locale: selectedLocale)
        ]).runValidation { [weak self] in
            guard let pool = optPool else {
                return
            }

            self?.delegate?.changePoolSelection(
                selectedPool: .init(poolStats: pool),
                isRecommended: false
            )

            self?.wireframe.complete(from: self?.view)
        }
    }

    func showPoolInfo(poolId: NominationPools.PoolId) {
        guard let view = view, let pool = poolStats.value?.first(where: { $0.poolId == poolId }) else {
            return
        }
        guard let address = try? pool.bondedAccountId.toAddress(using: chainAsset.chain.chainFormat) else {
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

extension NominationPoolSearchPresenter: NominationPoolSearchInteractorOutputProtocol {
    func didReceive(poolStats: [NominationPools.PoolStats]) {
        self.poolStats = .loaded(value: poolStats)
        provideVidewModel()
    }

    func didStartSearch(for _: String) {
        poolStats = .loading

        provideVidewModel()
    }

    func didReceive(maxMembersPerPool: UInt32?) {
        logger.debug("Max members per pool: \(String(describing: maxMembersPerPool))")

        self.maxMembersPerPool = maxMembersPerPool
    }

    func didReceive(error: NominationPoolSearchError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .pools:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refetchPools()
            }
        case .subscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .emptySearchResults:
            let emptyMessage = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSearchPoolEmpty()
            view?.didReceivePools(state: .error(emptyMessage))
        }
    }
}

extension NominationPoolSearchPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideVidewModel()
        }
    }
}
