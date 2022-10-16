import Foundation
import BigInt
import SoraFoundation

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol
    let viewModelFactory: ReferendumsModelFactoryProtocol
    let statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var freeBalance: BigUInt?
    private var chain: ChainModel?
    private var price: PriceData?
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var votes: [Referenda.ReferendumIndex: ReferendumAccountVoteLocal]?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?
    private var timeModels: [UInt: StatusTimeViewModel?]?

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        viewModelFactory: ReferendumsModelFactoryProtocol,
        statusViewModelFactory: ReferendumStatusViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.statusViewModelFactory = statusViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
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

    private func updateView() {
        guard let view = view else {
            return
        }
        guard let currentBlock = blockNumber,
              let blockTime = blockTime,
              let referendums = referendums,
              let chainModel = chain else {
            return
        }
        let sections = viewModelFactory.createSections(input: .init(
            referendums: referendums,
            metadataMapping: referendumsMetadata,
            votes: votes ?? [:],
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
}

extension ReferendumsPresenter: ReferendumsPresenterProtocol {
    func select(referendumIndex: UInt) {
        guard let referendum = referendums?.first(where: { $0.index == referendumIndex }) else {
            return
        }
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
}

extension ReferendumsPresenter: ReferendumsInteractorOutputProtocol {
    func didReceiveVotes(_ votes: [Referenda.ReferendumIndex: ReferendumAccountVoteLocal]) {
        self.votes = votes
    }

    func didReceiveReferendumsMetadata(_ metadata: ReferendumMetadataMapping?) {
        referendumsMetadata = metadata
        updateView()
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
        self.referendums = referendums.sorted(by: { $0.index < $1.index })
        updateView()
    }

    func didReceiveSelectedChain(_ chain: ChainModel) {
        self.chain = chain

        provideChainBalance()
        updateView()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        freeBalance = balance?.freeInPlank ?? 0

        provideChainBalance()
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price
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
        case .referendumsFetchFailed, .votesFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refresh()
            }
        case .blockNumberSubscriptionFailed, .priceSubscriptionFailed, .balanceSubscriptionFailed,
             .metadataSubscriptionFailed, .blockTimeServiceFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .blockTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retryBlockTime()
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
        freeBalance = nil
        price = nil

        provideChainBalance()

        interactor.saveSelected(chainModel: chainAsset.chain)
    }
}

extension ReferendumsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideChainBalance()

            updateView()
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
