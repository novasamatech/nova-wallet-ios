import Foundation
import BigInt
import SoraFoundation
import RobinHood

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol
    let viewModelFactory: ReferendumsModelFactoryProtocol
    let activityViewModelFactory: ReferendumsActivityViewModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let sorting: ReferendumsSorting
    let logger: LoggerProtocol

    private var freeBalance: BigUInt?
    private var selectedOption: GovernanceSelectedOption?
    private var price: PriceData?
    private var referendums: [ReferendumLocal]?
    private var filteredReferendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var offchainVoting: GovernanceOffchainVotesLocal?
    private var unlockSchedule: GovernanceUnlockSchedule?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var timeModels: [UInt: StatusTimeViewModel?]?
    private var filter = ReferendumsFilter.all

    private var chain: ChainModel? {
        selectedOption?.chain
    }

    private var governanceType: GovernanceType? {
        selectedOption?.type
    }

    private var supportsDelegations: Bool = false

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    deinit {
        invalidateTimer()
    }

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        viewModelFactory: ReferendumsModelFactoryProtocol,
        activityViewModelFactory: ReferendumsActivityViewModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        sorting: ReferendumsSorting,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.activityViewModelFactory = activityViewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.sorting = sorting
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func clearOnAssetSwitch() {
        invalidateTimer()

        freeBalance = nil
        price = nil
        referendums = nil
        filteredReferendums = nil
        referendumsMetadata = nil
        voting = nil
        offchainVoting = nil
        unlockSchedule = nil
        blockNumber = nil
        blockTime = nil
        maxStatusTimeInterval = nil
        timeModels = nil
        supportsDelegations = false

        view?.update(model: .init(sections: viewModelFactory.createLoadingViewModel()))
    }

    private func provideChainBalance() {
        guard
            let chain = chain,
            let governanceType = governanceType,
            let asset = chain.utilityAsset() else {
            return
        }

        let viewModel = chainBalanceFactory.createViewModel(
            from: governanceType.title(for: chain),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: freeBalance,
            locale: selectedLocale
        )

        view?.didReceiveChainBalance(viewModel: viewModel)
    }

    private func updateReferendumsView() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber,
              let blockTime = blockTime,
              let referendums = filteredReferendums,
              let chainModel = chain else {
            return
        }

        let accountVotes = voting?.value?.votes
        let referendumsSections = viewModelFactory.createSections(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: accountVotes?.votes ?? [:],
            offchainVotes: offchainVoting,
            chainInfo: .init(chain: chainModel, currentBlock: currentBlock, blockDuration: blockTime),
            locale: selectedLocale,
            voterName: nil
        ))

        let activitySection: ReferendumsSection

        if supportsDelegations {
            activitySection = activityViewModelFactory.createReferendumsActivitySection(
                chain: chainModel,
                voting: voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                locale: selectedLocale
            )
        } else {
            activitySection = activityViewModelFactory.createReferendumsActivitySectionWithoutDelegations(
                chain: chainModel,
                voting: voting?.value,
                blockNumber: currentBlock,
                unlockSchedule: unlockSchedule,
                locale: selectedLocale
            )
        }

        let settingsSection = ReferendumsSection.settings(isFilterOn: filter != .all)

        let allSections = [activitySection, settingsSection] + referendumsSections
        view.update(model: .init(sections: allSections))
    }

    private func updateTimeModels() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber, let blockTime = blockTime, let referendums = filteredReferendums else {
            return
        }

        let timeModels = statusViewModelFactory.createTimeViewModels(
            referendums: referendums,
            currentBlock: currentBlock,
            blockDuration: blockTime,
            locale: selectedLocale
        )

        self.timeModels = timeModels
        maxStatusTimeInterval = timeModels.compactMap { $0.value?.timeInterval }.max(by: <)
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
        guard let maxStatusTimeInterval = maxStatusTimeInterval else {
            return
        }

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: maxStatusTimeInterval)
    }

    private func updateTimerDisplay() {
        guard
            let view = view,
            let maxStatusTimeInterval = maxStatusTimeInterval,
            let remainedTimeInterval = countdownTimer?.remainedInterval,
            let timeModels = timeModels else {
            return
        }

        let elapsedTime = maxStatusTimeInterval >= remainedTimeInterval ?
            maxStatusTimeInterval - remainedTimeInterval : 0

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

    private func refreshUnlockSchedule() {
        guard let tracksVoting = voting?.value else {
            return
        }

        interactor.refreshUnlockSchedule(for: tracksVoting, blockHash: nil)
    }
}

extension ReferendumsPresenter: ReferendumsPresenterProtocol {
    func showFilters() {
        wireframe.showFilters(
            from: view,
            delegate: self,
            filter: filter
        )
    }

    func showSearch() {
        // TODO: Task #85zrwjtzu
    }

    func select(referendumIndex: UInt) {
        guard let referendum = filteredReferendums?.first(where: { $0.index == referendumIndex }) else {
            return
        }

        let accountVotes = voting?.value?.votes.votes[referendum.index]
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
            votingResult: voting,
            unlockSchedule: unlockSchedule,
            blockNumber: blockNumber,
            blockTime: blockTime
        )

        wireframe.showUnlocksDetails(from: view, initData: initData)
    }

    func selectDelegations() {
        let delegatings = voting?.value?.votes.delegatings ?? [:]

        if delegatings.isEmpty {
            wireframe.showAddDelegation(from: view)
        } else {
            wireframe.showYourDelegations(from: view)
        }
    }
}

extension ReferendumsPresenter: VoteChildPresenterProtocol {
    func setup() {
        view?.update(model: .init(sections: viewModelFactory.createLoadingViewModel()))
        interactor.setup()
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }

    func selectChain() {
        wireframe.selectChain(
            from: view,
            delegate: self,
            chainId: chain?.chainId,
            governanceType: governanceType
        )
    }
}

extension ReferendumsPresenter: ReferendumsInteractorOutputProtocol {
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        self.voting = voting
        updateReferendumsView()

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

            updateReferendumsView()
        }
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refresh()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        updateTimeModels()
    }

    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums.sorted { sorting.compare(referendum1: $0, referendum2: $1) }
        filteredReferendums = referendums.filter(filter.match)
        updateReferendumsView()
        updateTimeModels()
        refreshUnlockSchedule()
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
                self?.interactor.refresh()
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

extension ReferendumsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideChainBalance()

            updateReferendumsView()
        }
    }
}

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

extension ReferendumsPresenter: ReferendumsFiltersDelegate {
    func didUpdate(filter: ReferendumsFilter) {
        self.filter = filter
        filteredReferendums = referendums?.filter(filter.match)
        updateReferendumsView()
    }
}
