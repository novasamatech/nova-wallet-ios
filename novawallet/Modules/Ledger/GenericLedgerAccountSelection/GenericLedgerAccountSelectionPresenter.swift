import Foundation
import Operation_iOS

final class GenericLedgerAccountSelectionPresenter {
    weak var view: GenericLedgerAccountSelectionViewProtocol?
    let wireframe: GenericLedgerAccountSelectionWireframeProtocol
    let interactor: GenericLedgerAccountSelectionInteractorInputProtocol

    private var availableChainAssets: [ChainAsset] = []
    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var selectedChainAsset: ChainAsset?
    private var accounts: [LedgerAccountAmount] = []

    init(
        interactor: GenericLedgerAccountSelectionInteractorInputProtocol,
        wireframe: GenericLedgerAccountSelectionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func performLoadNext() {
        let index = accounts.count

        guard index <= UInt32.max, let selectedChainAsset else {
            return
        }

        interactor.loadBalance(for: selectedChainAsset, at: UInt32(index))
    }

    private func shouldSwitchSelectedAsset() -> Bool {
        guard let selectedChainAsset, let chain = chains[selectedChainAsset.chain.chainId] else {
            return true
        }

        return selectedChainAsset.asset != chain.utilityAsset()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension GenericLedgerAccountSelectionPresenter: GenericLedgerAccountSelectionInteractorOutputProtocol {
    func didReceiveLedgerChain(changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
        availableChainAssets = Array(chains.values).sortedUsingDefaultComparator().compactMap { $0.utilityChainAsset() }

        if shouldSwitchSelectedAsset() {
            selectedChainAsset = availableChainAssets.first
            accounts = []

            performLoadNext()
        }
    }

    func didReceive(accountBalance _: LedgerAccountAmount, at _: UInt32) {}

    func didReceive(error _: GenericLedgerAccountSelectionInteractorError) {}
}
