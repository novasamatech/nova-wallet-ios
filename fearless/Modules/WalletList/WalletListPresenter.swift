import Foundation
import RobinHood
import SubstrateSdk

final class WalletListPresenter {
    weak var view: WalletListViewProtocol?
    let wireframe: WalletListWireframeProtocol
    let interactor: WalletListInteractorInputProtocol

    private var connectionListDifference: ListDifferenceCalculator<ChainModel> = ListDifferenceCalculator(
        initialItems: [],
        sortBlock: { $0.addressPrefix < $1.addressPrefix }
    )
    private var connectionStates: [ChainModel.Id: WebSocketEngine.State] = [:]
    private var priceResult: Result<[ChainModel.Id: PriceData], Error>?
    private var accountResults: [ChainModel.Id: Result<AccountInfo?, Error>] = [:]

    init(
        interactor: WalletListInteractorInputProtocol,
        wireframe: WalletListWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletListPresenter: WalletListPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension WalletListPresenter: WalletListInteractorOutputProtocol {
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        connectionStates[chainId] = state
    }

    func didReceivePrices(result: Result<[ChainModel.Id: PriceData], Error>) {
        priceResult = result
    }

    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        connectionListDifference.apply(changes: changes)
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, chainId: ChainModel.Id) {
        accountResults[chainId] = result
    }
}
