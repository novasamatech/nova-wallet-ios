import Foundation
import BigInt
import SoraFoundation
import Operation_iOS

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol
    let viewModelFactory: ReferendumsModelFactoryProtocol
    let swipeGovViewModelFactory: SwipeGovViewModelFactoryProtocol
    let activityViewModelFactory: ReferendumsActivityViewModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let sorting: ReferendumsSorting
    let logger: LoggerProtocol

    private(set) lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    private(set) var freeBalance: BigUInt?
    private(set) var selectedOption: GovernanceSelectedOption?
    private(set) var price: PriceData?
    private(set) var sortedReferendums: [ReferendumLocal]?
    private(set) var filteredReferendums: [ReferendumIdLocal: ReferendumLocal] = [:]
    private(set) var referendumsMetadata: ReferendumMetadataMapping?
    private(set) var offchainVoting: GovernanceOffchainVotesLocal?
    private(set) var unlockSchedule: GovernanceUnlockSchedule?
    private(set) var blockNumber: BlockNumber?
    private(set) var blockTime: BlockTime?
    private(set) var supportsDelegations: Bool = false

    private(set) var maxStatusTimeInterval: TimeInterval?
    var countdownTimer: CountdownTimer?
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]? {
        didSet {
            observableViewState.state.timeModels = timeModels
        }
    }

    private(set) var filter = ReferendumsFilter.all

    let observableState: ReferendumsObservableState
    let observableViewState = Observable<ReferendumsViewState>(
        state: .init(cells: [], timeModels: nil)
    )

    var referendumsInitState: ReferendumsInitState?

    var chain: ChainModel? {
        selectedOption?.chain
    }

    var supportsSwipeGov: Bool? {
        selectedOption?.supportsSwipeGov()
    }

    var governanceType: GovernanceType? {
        selectedOption?.type
    }

    deinit {
        invalidateTimer()
    }

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        observableState: ReferendumsObservableState,
        viewModelFactory: ReferendumsModelFactoryProtocol,
        swipeGovViewModelFactory: SwipeGovViewModelFactoryProtocol,
        activityViewModelFactory: ReferendumsActivityViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        sorting: ReferendumsSorting,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.observableState = observableState
        self.viewModelFactory = viewModelFactory
        self.swipeGovViewModelFactory = swipeGovViewModelFactory
        self.activityViewModelFactory = activityViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.sorting = sorting
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func filterReferendums() {
        filteredReferendums = sortedReferendums?.filter {
            filter.match(
                $0,
                voting: observableState.voting,
                offchainVoting: offchainVoting
            )
        }.reduce(into: [ReferendumIdLocal: ReferendumLocal]()) {
            $0[$1.index] = $1
        } ?? [:]
        updateReferendumsView()
    }

    private func refreshUnlockSchedule() {
        guard let tracksVoting = observableState.voting?.value else {
            return
        }

        interactor.refreshUnlockSchedule(for: tracksVoting, blockHash: nil)
    }

    func clearState() {
        freeBalance = nil
        price = nil
        sortedReferendums = nil
        observableState.state = .init(value: ReferendumsState())
        filteredReferendums = [:]
        referendumsMetadata = nil
        offchainVoting = nil
        unlockSchedule = nil
        blockNumber = nil
        blockTime = nil
        maxStatusTimeInterval = nil
        timeModels = nil
        supportsDelegations = false
    }

    func updateTimeModels(
        with newModels: [ReferendumIdLocal: StatusTimeViewModel?],
        updatingMaxStatusTimeInterval: Bool
    ) {
        timeModels = newModels

        if updatingMaxStatusTimeInterval {
            maxStatusTimeInterval = newModels
                .compactMap { $0.value?.timeInterval }
                .max(by: <)
        }
    }
}

// MARK: Timers

extension ReferendumsPresenter {
    func invalidateTimer() {
        countdownTimer?.delegate = nil
        countdownTimer?.stop()
        countdownTimer = nil
    }

    func setupTimer() {
        guard let maxStatusTimeInterval = maxStatusTimeInterval else {
            return
        }

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: maxStatusTimeInterval)
    }
}

// MARK: ReferendumsPresenterProtocol

extension ReferendumsPresenter: ReferendumsPresenterProtocol {
    func showFilters() {
        wireframe.showFilters(
            from: view,
            delegate: self,
            filter: filter
        )
    }

    func showSearch() {
        wireframe.showSearch(
            from: view,
            referendumsState: observableViewState,
            delegate: self
        )
    }

    func select(referendumIndex: UInt) {
        guard let referendum = sortedReferendums?.first(where: { $0.index == referendumIndex }) else {
            return
        }

        showDetails(referendum: referendum)
    }

    func showDetails(referendum: ReferendumLocal) {
        let accountVotes = observableState.voting?.value?.votes.votes[referendum.index]
        let initData = ReferendumDetailsInitData(
            referendum: referendum,
            offchainVoting: offchainVoting?.fetchVotes(for: referendum.index),
            blockNumber: blockNumber,
            blockTime: blockTime,
            metadata: referendumsMetadata?[referendum.index],
            accountVotes: accountVotes
        )

        wireframe.showReferendumDetails(from: view, initData: initData)
    }

    func selectUnlocks() {
        let initData = GovernanceUnlockInitData(
            votingResult: observableState.voting,
            unlockSchedule: unlockSchedule,
            blockNumber: blockNumber,
            blockTime: blockTime
        )

        wireframe.showUnlocksDetails(from: view, initData: initData)
    }

    func selectDelegations() {
        let delegatings = observableState.voting?.value?.votes.delegatings ?? [:]

        if delegatings.isEmpty {
            wireframe.showAddDelegation(from: view)
        } else {
            wireframe.showYourDelegations(from: view)
        }
    }

    func selectSwipeGov() {
        wireframe.showSwipeGov(from: view)
    }

    func showReferendumDetailsIfNeeded() {
        guard let referendumsState = referendumsInitState,
              let referendums = sortedReferendums,
              !referendums.isEmpty else {
            return
        }
        let referendumIndex = referendumsState.referendumIndex
        referendumsState.stateHandledClosure()
        referendumsInitState = nil

        if let referendum = referendums.first(where: { $0.index == referendumIndex }) {
            showDetails(referendum: referendum)
        } else {
            let message = R.string.localizable.governanceReferendumNotFoundMessage(
                preferredLanguages: selectedLocale.rLanguages)
            let closeAction = R.string.localizable.commonOk(
                preferredLanguages: selectedLocale.rLanguages)
            wireframe.present(
                message: message,
                title: nil,
                closeAction: closeAction,
                from: view
            )
        }
    }
}

// MARK: ReferendumsInteractorOutputProtocol

extension ReferendumsPresenter: ReferendumsInteractorOutputProtocol {
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        observableState.update(with: voting)

        filterReferendums()

        if let tracksVoting = voting.value {
            interactor.refreshUnlockSchedule(for: tracksVoting, blockHash: voting.blockHash)
        }
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

    func didReceiveOffchainVoting(_ voting: GovernanceOffchainVotesLocal) {
        if offchainVoting != voting {
            offchainVoting = voting
            filterReferendums()
        }
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refreshReferendums()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        updateTimeModels()
    }

    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        sortedReferendums = referendums.sorted {
            sorting.compare(
                referendum1: $0,
                referendum2: $1
            )
        }

        observableState.update(with: .init(from: referendums))
        filterReferendums()
        updateTimeModels()
        refreshUnlockSchedule()
        showReferendumDetailsIfNeeded()
    }

    func didReceiveSelectedOption(_ option: GovernanceSelectedOption) {
        selectedOption = option

        provideChainBalance()
        updateReferendumsView()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        freeBalance = balance?.freeInPlank ?? 0

        provideChainBalance()
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price
    }

    func didReceiveUnlockSchedule(_ unlockSchedule: GovernanceUnlockSchedule) {
        self.unlockSchedule = unlockSchedule
        updateReferendumsView()
    }

    func didReceiveSupportDelegations(_ supportsDelegations: Bool) {
        self.supportsDelegations = supportsDelegations

        updateReferendumsView()
    }

    func didReceiveError(_ error: ReferendumsInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .settingsLoadFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.setup()
            }
        case .chainSaveFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                if let option = self?.selectedOption {
                    self?.interactor.saveSelected(option: option)
                }
            }
        case .referendumsFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshReferendums()
            }
        case .blockNumberSubscriptionFailed, .priceSubscriptionFailed, .balanceSubscriptionFailed,
             .metadataSubscriptionFailed, .blockTimeServiceFailed, .votingSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .blockTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBlockTime()
            }
        case .unlockScheduleFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshUnlockSchedule()
            }
        case .offchainVotingFetchFailed:
            // we don't bother user with offchain retry and wait next block
            break
        }
    }
}

// MARK: GovernanceAssetSelectionDelegate

extension ReferendumsPresenter: GovernanceAssetSelectionDelegate {
    func governanceAssetSelection(
        view _: AssetSelectionViewProtocol,
        didCompleteWith option: GovernanceSelectedOption
    ) {
        if selectedOption == option {
            return
        }

        selectedOption = option

        clearOnAssetSwitch()
        provideChainBalance()

        interactor.saveSelected(option: option)
    }
}

// MARK: CountdownTimerDelegate

extension ReferendumsPresenter: CountdownTimerDelegate {
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

// MARK: ReferendumsFiltersDelegate

extension ReferendumsPresenter: ReferendumsFiltersDelegate {
    func didUpdate(filter: ReferendumsFilter) {
        self.filter = filter
        filterReferendums()
    }
}

// MARK: ReferendumSearchDelegate

extension ReferendumsPresenter: ReferendumSearchDelegate {
    func didSelectReferendum(referendumIndex: ReferendumIdLocal) {
        select(referendumIndex: referendumIndex)
    }
}

// MARK: Localizable

extension ReferendumsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideChainBalance()

            updateReferendumsView()
        }
    }
}
