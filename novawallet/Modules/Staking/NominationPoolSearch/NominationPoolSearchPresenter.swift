import Foundation
import SoraFoundation
import RobinHood

final class NominationPoolSearchPresenter: AnyCancellableCleaning {
    weak var view: NominationPoolSearchViewProtocol?
    weak var delegate: StakingSelectPoolDelegate?

    let wireframe: NominationPoolSearchWireframeProtocol
    let interactor: NominationPoolSearchInteractorInputProtocol
    let viewModelFactory: StakingSelectPoolViewModelFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    private var poolStats: LoadableViewModelState<[NominationPools.PoolStats]> = .loaded(value: [])

    init(
        interactor: NominationPoolSearchInteractorInputProtocol,
        wireframe: NominationPoolSearchWireframeProtocol,
        viewModelFactory: StakingSelectPoolViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        delegate: StakingSelectPoolDelegate,
        operationQueue: OperationQueue,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
                selectedPoolId: nil,
                chainAsset: chainAsset,
                locale: selectedLocale
            )
            view?.didReceivePools(state: .loaded(viewModel: viewModel))
        }
    }

    private func showUnsupportedPoolStateAlert() {
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: selectedLocale.rLanguages)
        let message = R.string.localizable.stakingSearchPoolSelectionErrorMessage(
            preferredLanguages: selectedLocale.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        wireframe.present(message: message, title: title, closeAction: closeAction, from: view)
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
        guard let pool = poolStats.value?.first(where: { $0.poolId == poolId }) else {
            return
        }

        switch pool.state {
        case .blocked, .destroying, .unsuppored, .none:
            showUnsupportedPoolStateAlert()
        case .open:
            delegate?.changePoolSelection(
                selectedPool: .init(poolStats: pool),
                isRecommended: false
            )
            wireframe.complete(from: view)
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
            let emptyMessage = R.string.localizable.stakingSearchPoolEmpty(
                preferredLanguages: selectedLocale.rLanguages)
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
