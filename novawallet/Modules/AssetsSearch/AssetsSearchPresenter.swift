import Foundation
import BigInt
import RobinHood

final class AssetsSearchPresenter {
    weak var view: AssetsSearchViewProtocol?
    let wireframe: AssetsSearchWireframeProtocol
    let interactor: AssetsSearchInteractorInputProtocol

    private(set) var priceResult: Result<[ChainAssetId: PriceData], Error>?
    private(set) var balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:]
    private(set) var allChains: [ChainModel.Id: ChainModel] = [:]

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        wireframe: AssetsSearchWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AssetsSearchPresenter: AssetsSearchPresenterProtocol {
    func setup() {}
}

extension AssetsSearchPresenter: AssetsSearchInteractorOutputProtocol {
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>]) {
        allChains = changes.reduce(into: allChains) { result, change in
            switch change {
            case let .insert(newItem):
                result[newItem.chainId] = newItem
            case let .update(newItem):
                result[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }
    }

    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>]) {
        for (chainAssetId, result) in results {
            switch result {
            case let .success(maybeAmount):
                if let amount = maybeAmount {
                    balanceResults[chainAssetId] = .success(amount)
                } else if balanceResults[chainAssetId] == nil {
                    balanceResults[chainAssetId] = .success(0)
                }
            case let .failure(error):
                balanceResults[chainAssetId] = .failure(error)
            }
        }
    }

    func didReceivePrices(result _: Result<[ChainAssetId: PriceData], Error>?) {}
}
