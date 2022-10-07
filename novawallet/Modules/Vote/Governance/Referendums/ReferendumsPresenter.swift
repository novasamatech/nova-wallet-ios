import Foundation
import BigInt
import SoraFoundation

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol

    private var freeBalance: BigUInt?
    private var chain: ChainModel?
    private var price: PriceData?
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: [Referenda.ReferendumIndex: ReferendumMetadataLocal]?
    private var blockNumber: BlockNumber?

    private lazy var chainBalanceFactory = ChainBalanceViewModelFactory()

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        self.blockNumber = blockNumber
    }

    func didReceiveReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums
    }

    func didReceiveSelectedChain(_ chain: ChainModel) {
        self.chain = chain

        provideChainBalance()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        freeBalance = balance?.freeInPlank ?? 0

        provideChainBalance()
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price
    }

    func didReceiveError(_: ReferendumsInteractorError) {}
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
        }
    }
}
