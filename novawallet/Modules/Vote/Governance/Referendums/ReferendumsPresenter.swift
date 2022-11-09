import Foundation
import BigInt
import SoraFoundation
import RobinHood

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol
    let viewModelFactory: ReferendumsModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let sorting: ReferendumsSorting
    let logger: LoggerProtocol

    private var freeBalance: BigUInt?
    private var chain: ChainModel?
    private var price: PriceData?
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var unlockSchedule: GovernanceUnlockSchedule?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var timeModels: [UInt: StatusTimeViewModel?]?

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    deinit {
        invalidateTimer()
    }

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        viewModelFactory: ReferendumsModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        sorting: ReferendumsSorting,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
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
        referendumsMetadata = nil
        voting = nil
        blockNumber = nil
        blockTime = nil
        maxStatusTimeInterval = nil
        timeModels = nil

        view?.didReceiveUnlocks(viewModel: nil)
        view?.update(model: .init(sections: []))
    }

    private func provideChainBalance() {
        guard let chain = chain, let asset = chain.utilityAsset() else {
            return
        }

        let viewModel = chainBalanceFactory.createViewModel(
            from: ChainAsset(chain: chain, asset: asset),
            balanceInPlank: freeBalance,
            locale: selectedLocale
        )

        view?.didReceiveChainBalance(viewModel: viewModel)
    }

    private func updateUnlocksView() {
        guard
            let totalLocked = voting?.value?.totalLocked(),
            totalLocked > 0,
            let displayInfo = chain?.utilityAssetDisplayInfo()
        else {
            view?.didReceiveUnlocks(viewModel: nil)
            return
        }

        let totalLockedDecimal = Decimal.fromSubstrateAmount(totalLocked, precision: displayInfo.assetPrecision) ?? 0

        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        let totalLockedString = tokenFormatter.value(for: selectedLocale).stringFromDecimal(totalLockedDecimal)

        let hasUnlock: Bool

        if let blockNumber = blockNumber, let unlockSchedule = unlockSchedule {
            hasUnlock = unlockSchedule.availableUnlock(at: blockNumber).amount > 0
        } else {
            hasUnlock = false
        }

        let viewModel = ReferendumsUnlocksViewModel(totalLock: totalLockedString ?? "", hasUnlock: hasUnlock)
        view?.didReceiveUnlocks(viewModel: viewModel)
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
        let sections = viewModelFactory.createSections(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: accountVotes?.votes ?? [:],
            chainInfo: .init(chain: chainModel, currentBlock: currentBlock, blockDuration: blockTime),
            locale: selectedLocale
        ))

        view.update(model: .init(sections: sections))
    }

    private func updateTimeModels() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber, let blockTime = blockTime, let referendums = referendums else {
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
                timeInterval: remainedTime,
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
    func select(referendumIndex: UInt) {
        guard let referendum = referendums?.first(where: { $0.index == referendumIndex }) else {
            return
        }

        let accountVotes = voting?.value?.votes

        wireframe.showReferendumDetails(
            from: view,
            referendum: referendum,
            accountVotes: accountVotes?.votes[referendum.index],
            metadata: referendumsMetadata?[referendum.index]
        )
    }
}

extension ReferendumsPresenter: VoteChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func becomeOnline() {
        interactor.becomeOnline()
    }

    func putOffline() {
        interactor.putOffline()
    }

    func selectChain() {
        guard let chain = chain, let asset = chain.utilityAsset() else {
            return
        }

        let chainAssetId = ChainAsset(chain: chain, asset: asset).chainAssetId

        wireframe.selectChain(
            from: view,
            delegate: self,
            selectedChainAssetId: chainAssetId
        )
    }

    func selectUnlocks() {
        wireframe.showUnlocksDetails(from: view)
    }
}

extension ReferendumsPresenter: ReferendumsInteractorOutputProtocol {
    func didReceiveVoting(_ voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        self.voting = voting
        updateReferendumsView()
        updateUnlocksView()

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

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refresh()
        updateTimeModels()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        updateTimeModels()
    }

    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums.sorted { sorting.compare(referendum1: $0, referendum2: $1) }

        updateReferendumsView()
        updateTimeModels()

        refreshUnlockSchedule()
    }

    func didReceiveSelectedChain(_ chain: ChainModel) {
        self.chain = chain

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
        updateUnlocksView()
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
                if let chain = self?.chain {
                    self?.interactor.saveSelected(chainModel: chain)
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
        }
    }
}

extension ReferendumsPresenter: AssetSelectionDelegate {
    func assetSelection(view _: AssetSelectionViewProtocol, didCompleteWith chainAsset: ChainAsset) {
        if chain?.chainId == chainAsset.chain.chainId {
            return
        }

        chain = chainAsset.chain

        clearOnAssetSwitch()

        provideChainBalance()

        interactor.saveSelected(chainModel: chainAsset.chain)
    }
}

extension ReferendumsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideChainBalance()

            updateReferendumsView()
            updateUnlocksView()
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
