import Foundation
import Foundation_iOS
import Operation_iOS

final class SwipeGovVotingListPresenter {
    weak var view: SwipeGovVotingListViewProtocol?

    private let wireframe: SwipeGovVotingListWireframeProtocol
    private let interactor: SwipeGovVotingListInteractorInputProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let chain: ChainModel

    private let observableState: ReferendumsObservableState

    private let votingListViewModelFactory: SwipeGovVotingListViewModelFactory
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let govBalanceCalculator: AvailableBalanceMapping

    private var votingListItems: [VotingBasketItemLocal] = []
    private var referendumsMetadata: [ReferendumMetadataLocal] = []
    private var balance: AssetBalance?
    private var isActive: Bool = false

    init(
        interactor: SwipeGovVotingListInteractorInputProtocol,
        wireframe: SwipeGovVotingListWireframeProtocol,
        chain: ChainModel,
        observableState: ReferendumsObservableState,
        votingListViewModelFactory: SwipeGovVotingListViewModelFactory,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.observableState = observableState
        self.votingListViewModelFactory = votingListViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.localizationManager = localizationManager
    }
}

// MARK: SwipeGovVotingListPresenterProtocol

extension SwipeGovVotingListPresenter: SwipeGovVotingListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func removeItem(with referendumId: ReferendumIdLocal) {
        showRemoveAlert(for: referendumId)
    }

    func selectVoting(for referendumId: ReferendumIdLocal) {
        guard let referendum = observableState.referendums[referendumId] else {
            return
        }

        let initData = ReferendumDetailsInitData(referendum: referendum)

        wireframe.showReferendumDetails(
            from: view,
            initData: initData
        )
    }

    func vote() {
        let initData = ReferendumVotingInitData(votingItems: votingListItems)
        wireframe.showConfirmation(from: view, initData: initData)
    }

    func becomeActive() {
        isActive = true

        interactor.becomeActive()
    }

    func becomeInactive() {
        isActive = false

        interactor.becomeInactive()
    }
}

// MARK: SwipeGovVotingListInteractorOutputProtocol

extension SwipeGovVotingListPresenter: SwipeGovVotingListInteractorOutputProtocol {
    func didReceive(_ referendumMetadataChanges: [DataProviderChange<ReferendumMetadataLocal>]) {
        referendumsMetadata = referendumsMetadata.applying(changes: referendumMetadataChanges)
        updateView()
    }

    func didReceive(_ votingBasketChanges: [DataProviderChange<VotingBasketItemLocal>]) {
        let deletes = votingBasketChanges
            .filter { $0.isDeletion }
            .compactMap { deletion in
                votingListItems.first(where: { $0.identifier == deletion.identifier })?.referendumId
            }

        votingListItems = votingListItems.applying(changes: votingBasketChanges)

        let proceedClosure: () -> Void = { [weak self] in
            guard let self else { return }
            if votingListItems.isEmpty {
                wireframe.close(view: view)
            } else {
                updateView()
            }
        }

        if !deletes.isEmpty, isActive {
            showReferendaExcluded(completion: proceedClosure)
        } else {
            proceedClosure()
        }
    }

    func didReceive(_ assetBalance: AssetBalance?) {
        balance = assetBalance
    }

    func didReceive(_ error: SwipeGovVotingListInteractorError) {
        let selectedLocale = localizationManager.selectedLocale

        switch error {
        case .assetBalanceFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.subscribeBalance()
            }
        case .metadataFailed:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.subscribeMetadata()
            }
        case .votingBasket:
            wireframe.presentRequestStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.subscribeVotingItems()
            }
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListPresenter {
    func updateView() {
        guard
            !referendumsMetadata.isEmpty,
            !votingListItems.isEmpty
        else {
            return
        }

        let viewModel = votingListViewModelFactory.createListViewModel(
            using: votingListItems,
            metadataItems: referendumsMetadata,
            chain: chain,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel)
    }
}

// MARK: Alerts

private extension SwipeGovVotingListPresenter {
    func showRemoveAlert(for referendumId: ReferendumIdLocal) {
        guard let removeItem = votingListItems.first(
            where: { $0.referendumId == referendumId }
        ) else {
            return
        }

        let action: () -> Void = { [weak self] in
            self?.votingListItems.removeAll(where: { $0.referendumId == referendumId })
            self?.interactor.removeItem(with: removeItem.identifier)
        }

        wireframe.presentRemoveListItem(
            from: view,
            for: removeItem,
            locale: localizationManager.selectedLocale,
            action: action
        )
    }

    func showReferendaExcluded(completion: @escaping () -> Void) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            completion()
            return
        }

        let availableBalance = govBalanceCalculator.availableBalanceElseZero(from: balance)

        let availableBalanceString = balanceViewModelFactory.amountFromValue(
            availableBalance.decimal(assetInfo: assetInfo)
        ).value(for: localizationManager.selectedLocale)

        wireframe.presentReferendaExcluded(
            from: view,
            availableBalance: availableBalanceString,
            locale: localizationManager.selectedLocale,
            action: completion
        )
    }
}
