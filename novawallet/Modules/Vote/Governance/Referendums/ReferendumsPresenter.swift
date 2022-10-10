import Foundation
import BigInt
import SoraFoundation

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol
    let logger: LoggerProtocol

    private var freeBalance: BigUInt?
    private var chain: ChainModel?
    private var price: PriceData?
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var votes: [Referenda.ReferendumIndex: ReferendumAccountVoteLocal]?
    private var blockNumber: BlockNumber?
    private let viewModelFactory: ReferendumsModelFactoryProtocol
    private var blockTime: BlockTime?

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        viewModelFactory: ReferendumsModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
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
              let metadataMapping = referendumsMetadata,
              let referendums = self.referendums,
              let chainModel = chain else {
            return
        }
        let sections = viewModelFactory.createSections(input: .init(
            referendums: referendums,
            metadataMapping: metadataMapping,
            chainInfo: .init(chain: chainModel, currentBlock: currentBlock, blockDurartion: blockTime),
            locale: selectedLocale
        ))

        view.update(model: .init(sections: sections))
    }
}

extension ReferendumsPresenter: ReferendumsPresenterProtocol {}

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
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber

        interactor.refresh()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
    }

    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums
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
