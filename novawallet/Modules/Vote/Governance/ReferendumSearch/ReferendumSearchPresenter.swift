import Foundation
import SoraFoundation
import RobinHood

final class ReferendumSearchPresenter {
    weak var view: ReferendumSearchViewProtocol?
    let wireframe: ReferendumSearchWireframeProtocol
    let interactor: ReferendumSearchInteractorInputProtocol
    let viewModelFactory: SearchReferendumsModelFactoryProtocol

    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var offchainVoting: GovernanceOffchainVotesLocal?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var chain: ChainModel?

    init(
        interactor: ReferendumSearchInteractorInputProtocol,
        wireframe: ReferendumSearchWireframeProtocol,
        viewModelFactory: SearchReferendumsModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func updateReferendumsView() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber,
              let blockTime = blockTime,
              let referendums = referendums,
              let chainModel = chain else {
            return
        }

        let accountVotes = voting?.value?.votes
        let referendumsViewModels = viewModelFactory.createReferendumsViewModel(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: accountVotes?.votes ?? [:],
            offchainVotes: offchainVoting,
            chainInfo: .init(chain: chainModel, currentBlock: currentBlock, blockDuration: blockTime),
            locale: selectedLocale,
            voterName: nil
        ))

        view.didReceive(viewModel: referendumsViewModels.isEmpty ? .notFound : .found(title: .init(title: ""), items: referendumsViewModels))
    }
}

extension ReferendumSearchPresenter: ReferendumSearchPresenterProtocol {
    func search(for _: String) {}

    func setup() {
        view?.didReceive(viewModel: .start)
        interactor.setup()
    }
}

extension ReferendumSearchPresenter: ReferendumSearchInteractorOutputProtocol {
    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums
        updateReferendumsView()
    }

    func didReceiveReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>]) {
        let indexedReferendums = Array((referendumsMetadata ?? [:]).values).reduceToDict()

        referendumsMetadata = changes.reduce(into: referendumsMetadata ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.referendumId] = newItem
            case let .delete(deletedIdentifier):
                if let referendumId = indexedReferendums[deletedIdentifier]?.referendumId {
                    accum[referendumId] = nil
                }
            }
        }

        updateReferendumsView()
    }

    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        self.voting = voting
        updateReferendumsView()
    }

    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotesLocal) {
        offchainVoting = voting
        updateReferendumsView()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber
        updateReferendumsView()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        updateReferendumsView()
    }

    func didRecieveChain(_ chainModel: ChainModel) {
        chain = chainModel
        updateReferendumsView()
    }

    func didReceiveError(_: ReferendumsInteractorError) {
        // TODO:
    }
}

extension ReferendumSearchPresenter: Localizable {
    func applyLocalization() {}
}
