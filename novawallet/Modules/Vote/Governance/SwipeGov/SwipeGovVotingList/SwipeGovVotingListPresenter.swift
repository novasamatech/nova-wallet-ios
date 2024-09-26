import Foundation
import SoraFoundation
import Operation_iOS

final class SwipeGovVotingListPresenter {
    weak var view: SwipeGovVotingListViewProtocol?

    private let wireframe: SwipeGovVotingListWireframeProtocol
    private let interactor: SwipeGovVotingListInteractorInputProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let chain: ChainModel
    private let metaAccount: MetaAccountModel

    private let observableState: ReferendumsObservableState

    private let viewModelFactory: SwipeGovVotingListViewModelFactory

    private var votingListItems: [VotingBasketItemLocal] = []
    private var referendumsMetadata: [ReferendumMetadataLocal] = []
    private var balance: AssetBalance?

    init(
        interactor: SwipeGovVotingListInteractorInputProtocol,
        wireframe: SwipeGovVotingListWireframeProtocol,
        chain: ChainModel,
        observableState: ReferendumsObservableState,
        metaAccount: MetaAccountModel,
        viewModelFactory: SwipeGovVotingListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.observableState = observableState
        self.metaAccount = metaAccount
        self.viewModelFactory = viewModelFactory
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
        validateBalanceSufficient { [weak self] in
            guard let self else { return }

            let initData = ReferendumVotingInitData(
                votingItems: votingListItems
            )

            wireframe.showConfirmation(
                from: view,
                initData: initData
            )
        }
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
                validateBalanceSufficient()
            }
        }

        if !deletes.isEmpty {
            showReferendaExcluded(completion: proceedClosure)
        } else {
            proceedClosure()
        }
    }

    func didReceive(_ assetBalance: AssetBalance?) {
        balance = assetBalance

        validateBalanceSufficient()
    }

    func didReceiveUnavailableItems() {
        let languages = localizationManager.selectedLocale.rLanguages

        wireframe.present(
            message: R.string.localizable.govVotingListItemUnavailableAlertMessage(
                preferredLanguages: languages
            ),
            title: R.string.localizable.govVotingListItemUnavailableAlertTitle(
                preferredLanguages: languages
            ),
            closeAction: R.string.localizable.commonOk(
                preferredLanguages: languages
            ),
            from: view
        )
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

        let viewModel = viewModelFactory.createListViewModel(
            using: votingListItems,
            metadataItems: referendumsMetadata,
            chain: chain,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModel)
    }

    func validateBalanceSufficient(_ closure: (() -> Void)? = nil) {
        guard let balance else {
            return
        }

        let invalidItems = lookForInvalidItems(in: votingListItems, for: balance)

        if !invalidItems.isEmpty, let max = invalidItems.max(by: { $0.amount < $1.amount }) {
            let votingPower = VotingPowerLocal(
                chainId: chain.chainId,
                metaId: metaAccount.metaId,
                conviction: max.conviction,
                amount: max.amount
            )

            showBalanceAlert(
                for: votingPower,
                invalidItems: invalidItems
            )
        } else {
            closure?()
        }
    }

    func lookForInvalidItems(
        in votingItems: [VotingBasketItemLocal],
        for balance: AssetBalance
    ) -> [VotingBasketItemLocal] {
        votingItems.filter { $0.amount > balance.freeInPlank }
    }
}

// MARK: Alerts

private extension SwipeGovVotingListPresenter {
    func showBalanceAlert(
        for votingPower: VotingPowerLocal,
        invalidItems: [VotingBasketItemLocal]
    ) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let model = SwipeGovBalanceAlertModel(
            votingPower: votingPower,
            invalidItems: invalidItems,
            assetInfo: assetInfo,
            changeAction: { [weak self] in
                self?.wireframe.showSetup(
                    from: self?.view,
                    initData: .init(presetVotingPower: votingPower),
                    changing: invalidItems
                )
            }
        )

        wireframe.presentBalanceAlert(
            from: view,
            model: model,
            locale: localizationManager.selectedLocale
        )
    }

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
        guard
            let balance,
            let assetInfo = chain.utilityAssetDisplayInfo()
        else {
            return
        }

        wireframe.presentReferendaExcluded(
            from: view,
            availableBalance: balance.transferable,
            assetInfo: assetInfo,
            locale: localizationManager.selectedLocale,
            action: completion
        )
    }
}
