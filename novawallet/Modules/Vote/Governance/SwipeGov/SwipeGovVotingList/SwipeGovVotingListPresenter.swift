import Foundation
import SoraFoundation
import Operation_iOS

final class SwipeGovVotingListPresenter {
    weak var view: SwipeGovVotingListViewProtocol?

    private let wireframe: SwipeGovVotingListWireframeProtocol
    private let interactor: SwipeGovVotingListInteractorInputProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let chain: ChainModel

    private let viewModelFactory: SwipeGovVotingListViewModelFactory

    private var votingListItems: [VotingBasketItemLocal] = []
    private var referendumsMetadata: [ReferendumMetadataLocal] = []
    private var balance: AssetBalance?

    init(
        interactor: SwipeGovVotingListInteractorInputProtocol,
        wireframe: SwipeGovVotingListWireframeProtocol,
        chain: ChainModel,
        viewModelFactory: SwipeGovVotingListViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
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
        guard let itemIdentifier = votingListItems.first(
            where: { $0.referendumId == referendumId }
        )?.identifier else {
            return
        }

        interactor.removeItem(with: itemIdentifier)
    }

    func selectVoting(for _: ReferendumIdLocal) {
        // TODO: Show referendum details
    }

    func vote() {
        // TODO: Show confirmation
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
            updateView(with: deletes)
        }
    }

    func didReceive(_ assetBalance: AssetBalance?) {
        balance = assetBalance
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

    func didReceive(_ error: Error) {
        print(error)
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
}
