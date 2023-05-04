import Foundation
import SoraFoundation
import RobinHood

final class ReferendumSearchPresenter {
    weak var view: ReferendumSearchViewProtocol?
    let wireframe: ReferendumSearchWireframeProtocol
    let interactor: ReferendumSearchInteractorInputProtocol
    let viewModelFactory: SearchReferendumsModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let logger: LoggerProtocol?

    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var offchainVoting: GovernanceOffchainVotesLocal?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var chain: ChainModel?

    private var maxTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var timeModels: [UInt: StatusTimeViewModel?]?
    private weak var delegate: ReferendumSearchDelegate?

    init(
        interactor: ReferendumSearchInteractorInputProtocol,
        wireframe: ReferendumSearchWireframeProtocol,
        viewModelFactory: SearchReferendumsModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        delegate: ReferendumSearchDelegate?,
        logger: LoggerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.delegate = delegate
        self.logger = logger
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
    func search(for text: String) {
        interactor.search(text: text)
    }

    func setup() {
        view?.didReceive(viewModel: .start)
        interactor.setup()
    }

    func cancel() {
        wireframe.finish(from: view)
    }
}

extension ReferendumSearchPresenter: ReferendumSearchInteractorOutputProtocol {
    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums
        updateReferendumsView()
        updateTimeModels()
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

    func didReceiveReferendumsMetadata(_ referendumsMetadata: ReferendumMetadataMapping?) {
        self.referendumsMetadata = referendumsMetadata
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
        updateTimeModels()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        updateReferendumsView()
        updateTimeModels()
    }

    func didRecieveChain(_ chainModel: ChainModel) {
        chain = chainModel
        updateReferendumsView()
    }

    func didReceiveError(_ error: BaseReferendumsInteractorError) {
        logger?.error("Did receive error: \(error)")

        switch error {
        case .settingsLoadFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .referendumsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refresh()
            }
        case .blockNumberSubscriptionFailed, .metadataSubscriptionFailed, .blockTimeServiceFailed, .votingSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .blockTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBlockTime()
            }
        case .offchainVotingFetchFailed:
            // we don't bother user with offchain retry and wait next block
            break
        }
    }

    func didReceiveError(_ error: ReferendumSearchError) {
        switch error {
        case let .searchFailed(text, error):
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.search(text: text)
            }
        }
    }
}

extension ReferendumSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateReferendumsView()
        }
    }
}

extension ReferendumSearchPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateTimerDisplay()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateTimerDisplay()
    }

    func didStop(with _: TimeInterval) {
        updateTimerDisplay()
    }

    func select(referendumIndex: UInt) {
        delegate?.didSelectReferendum(referendumIndex: referendumIndex)
        wireframe.finish(from: view)
    }
}

extension ReferendumSearchPresenter {
    private func updateTimerDisplay() {
        guard
            let view = view,
            let maxTimeInterval = maxTimeInterval,
            let remainedTimeInterval = countdownTimer?.remainedInterval,
            let timeModels = timeModels else {
            return
        }

        let elapsedTime = maxTimeInterval >= remainedTimeInterval ?
            maxTimeInterval - remainedTimeInterval : 0

        let updatedTimeModels = timeModels.reduce(into: timeModels) { result, model in
            guard let timeModel = model.value,
                  let time = timeModel.timeInterval else {
                return
            }

            guard time > elapsedTime else {
                result[model.key] = nil
                return
            }
            let remainedTime = time - elapsedTime
            guard let updatedViewModel = timeModel.updateModelClosure(remainedTime) else {
                result[model.key] = nil
                return
            }

            result[model.key] = .init(
                viewModel: updatedViewModel,
                timeInterval: time,
                updateModelClosure: timeModel.updateModelClosure
            )
        }

        self.timeModels = updatedTimeModels
        view.updateReferendums(time: updatedTimeModels)
    }

    private func updateTimeModels() {
        guard let view = view else {
            return
        }
        guard
            let currentBlock = blockNumber,
            let blockTime = blockTime,
            let referendums = referendums else {
            return
        }

        let timeModels = statusViewModelFactory.createTimeViewModels(
            referendums: Array(referendums),
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: selectedLocale
        )

        self.timeModels = timeModels
        maxTimeInterval = timeModels.compactMap { $0.value?.timeInterval }.max(by: <)
        invalidateTimer()
        setupTimer()
        updateTimerDisplay()

        view.updateReferendums(time: timeModels)
    }

    private func invalidateTimer() {
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }

    private func setupTimer() {
        guard let maxTimeInterval = maxTimeInterval else {
            return
        }

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: maxTimeInterval)
    }
}
