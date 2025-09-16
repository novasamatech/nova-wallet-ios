import Foundation
import Operation_iOS
import Foundation_iOS

final class DelegateVotedReferendaPresenter {
    weak var view: DelegateVotedReferendaViewProtocol?
    let wireframe: DelegateVotedReferendaWireframeProtocol
    let interactor: DelegateVotedReferendaInteractorInputProtocol

    let viewModelFactory: DelegateReferendumsModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let sorting: ReferendumsSorting
    let logger: LoggerProtocol
    let name: String
    let chain: ChainModel
    let option: DelegateVotedReferendaOption

    private var referendums: [ReferendumLocal]?
    private var offchainVotes: GovernanceOffchainVotes?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var maxTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var timeModels: [UInt: StatusTimeViewModel?]?

    deinit {
        invalidateTimer()
    }

    init(
        interactor: DelegateVotedReferendaInteractorInputProtocol,
        wireframe: DelegateVotedReferendaWireframeProtocol,
        chain: ChainModel,
        viewModelFactory: DelegateReferendumsModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        sorting: ReferendumsSorting,
        name: String,
        localizationManager: LocalizationManagerProtocol,
        option: DelegateVotedReferendaOption,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.viewModelFactory = viewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.sorting = sorting
        self.logger = logger
        self.name = name
        self.option = option
        self.localizationManager = localizationManager
    }

    private func updateReferendumsView() {
        guard let view = view else {
            return
        }
        guard
            let currentBlock = blockNumber,
            let blockTime = blockTime,
            let referendums = referendums,
            let offchainVotes = offchainVotes else {
            return
        }

        let referendumsViewModels = viewModelFactory.createReferendumsViewModel(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: offchainVotes,
            offchainVotes: nil,
            chainInfo: .init(chain: chain, currentBlock: currentBlock, blockDuration: blockTime),
            locale: selectedLocale,
            voterName: name
        ))

        view.update(viewModels: referendumsViewModels)
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

    private var title: LocalizableResource<String> {
        switch option {
        case .allTimes:
            return LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.delegationsVotedReferendaTitle()
            }
        case let .recent(days):
            return LocalizableResource { locale in
                let formattedDays = R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonDaysFormat(format: days)
                return R.string(preferredLanguages: locale.rLanguages).localizable.delegationsLastVoted(formattedDays)
            }
        }
    }
}

extension DelegateVotedReferendaPresenter: DelegateVotedReferendaInteractorOutputProtocol {
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

    func didReceiveOffchainVoting(_ voting: DelegateVotedReferendaModel) {
        offchainVotes = voting.offchainVotes
        referendums = voting.referendums.values
            .sorted { $0.index > $1.index }

        updateReferendumsView()
        updateTimeModels()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        updateTimeModels()
    }

    func didReceiveError(_ error: DelegateVotedReferendaError) {
        switch error {
        case .blockNumberSubscriptionFailed, .metadataSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscription()
            }
        case .offchainVotingFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryOffchainVotingFetch()
            }
        case .blockTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBlockTime()
            }
        }
    }
}

extension DelegateVotedReferendaPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            view.update(title: title)
            updateReferendumsView()
        }
    }
}

extension DelegateVotedReferendaPresenter: DelegateVotedReferendaPresenterProtocol {
    func setup() {
        let loadingViewModel = viewModelFactory.createLoadingViewModel()
        view?.update(title: title)
        view?.update(viewModels: loadingViewModel)
        interactor.setup()
    }

    func selectReferendum(with referendumId: ReferendumIdLocal) {
        guard let referendum = referendums?.first(where: { $0.index == referendumId }) else {
            return
        }

        let details = ReferendumDetailsInitData(
            referendum: referendum,
            offchainVoting: nil,
            blockNumber: blockNumber,
            blockTime: blockTime,
            metadata: referendumsMetadata?[referendumId],
            accountVotes: offchainVotes?[referendumId],
            votingAvailable: false
        )

        wireframe.showReferendumDetails(
            from: view,
            initData: details
        )
    }
}

extension DelegateVotedReferendaPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateTimerDisplay()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateTimerDisplay()
    }

    func didStop(with _: TimeInterval) {
        updateTimerDisplay()
    }
}
