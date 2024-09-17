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
        guard let balance else {
            return
        }

        validateBalanceSufficient {
            // TODO: Show confirmation
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
            .map(\.identifier)
            .compactMap { identifier in
                votingListItems.first(where: { $0.identifier == identifier })?.referendumId
            }

        votingListItems = votingListItems.applying(changes: votingBasketChanges)

        if votingListItems.isEmpty {
            wireframe.close(view: view)
        } else {
            validateBalanceSufficient {
                self.updateView(with: deletes)
            }
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
    func updateView(with deletes: [ReferendumIdLocal]? = nil) {
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

        if let deletes, !deletes.isEmpty {
            deletes.forEach { referendumId in
                view?.didChangeViewModel(viewModel, byRemovingItemWith: referendumId)
            }
        } else {
            view?.didReceive(viewModel)
        }
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

            wireframe.showSetup(
                from: view,
                initData: .init(presetVotingPower: votingPower),
                changing: invalidItems
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

    func showRemoveAlert(for referendumId: ReferendumIdLocal) {
        guard let itemIdentifier = votingListItems.first(
            where: { $0.referendumId == referendumId }
        )?.identifier else {
            return
        }

        let languages = localizationManager.selectedLocale.rLanguages

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.govVotingListItemRemoveAlertTitle(
                Int(referendumId),
                preferredLanguages: languages
            ),
            message: R.string.localizable.govVotingListItemRemoveAlertMessage(
                preferredLanguages: languages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonCancel(
                        preferredLanguages: languages
                    ),
                    style: .cancel
                ),
                .init(
                    title: R.string.localizable.commonRemove(
                        preferredLanguages: languages
                    ),
                    style: .destructive,
                    handler: {
                        [weak self] in
                        self?.interactor.removeItem(with: itemIdentifier)
                    }
                )
            ],
            closeAction: nil
        )
        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }
}
