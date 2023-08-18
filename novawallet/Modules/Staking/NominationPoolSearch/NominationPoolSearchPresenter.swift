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
    let searchOperationFactory: NominationPoolSearchOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var poolStats: [NominationPools.PoolStats] = []
    private var currentSearchOperation: CancellableCall?
    private var searchOperationClosure: NominationPoolSearchOperationClosure?

    init(
        interactor: NominationPoolSearchInteractorInputProtocol,
        wireframe: NominationPoolSearchWireframeProtocol,
        viewModelFactory: StakingSelectPoolViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        searchOperationFactory: NominationPoolSearchOperationFactoryProtocol,
        delegate: StakingSelectPoolDelegate,
        operationQueue: OperationQueue
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.searchOperationFactory = searchOperationFactory
        self.operationQueue = operationQueue
        self.delegate = delegate
    }

    private func provideVidewModel() {
        let viewModel = viewModelFactory.createStakingSelectPoolViewModels(
            from: poolStats,
            selectedPoolId: nil,
            chainAsset: chainAsset,
            locale: selectedLocale
        )
        searchOperationClosure = searchOperationFactory.createOperationClosure(viewModels: viewModel)
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

    func search(for text: String) {
        guard let searchOperationClosure = searchOperationClosure else {
            return
        }
        if text.isEmpty {
            view?.didReceivePools(state: .loaded(viewModel: []))
        } else {
            clear(cancellable: &currentSearchOperation)
            let searchOperation = searchOperationClosure(text)
            searchOperation.completionBlock = { [weak self] in
                let result = (try? searchOperation.extractNoCancellableResultData()) ?? []

                DispatchQueue.main.async {
                    if !result.isEmpty {
                        self?.view?.didReceivePools(state: .loaded(viewModel: result))
                    } else {
                        let emptyMessage = R.string.localizable.stakingSearchPoolEmpty(
                            preferredLanguages: self?.selectedLocale.rLanguages)
                        self?.view?.didReceivePools(state: .error(emptyMessage))
                    }
                }
            }
            currentSearchOperation = searchOperation
            operationQueue.addOperation(searchOperation)
        }
    }

    func selectPool(poolId: NominationPools.PoolId) {
        guard let pool = poolStats.first(where: { $0.poolId == poolId }) else {
            return
        }

        if pool.maxApy == nil {
            showUnsupportedPoolStateAlert()
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
        guard let view = view, let pool = poolStats.first(where: { $0.poolId == poolId }) else {
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
        self.poolStats = poolStats
        provideVidewModel()
    }

    func didReceive(error: NominationPoolSearchError) {
        switch error {
        case .pools:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refetchPools()
            }
        case .subscription:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
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
