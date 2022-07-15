import Foundation
import BigInt
import RobinHood

final class AssetsSearchPresenter {
    weak var view: AssetsSearchViewProtocol?
    let wireframe: AssetsSearchWireframeProtocol
    let interactor: AssetsSearchInteractorInputProtocol

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
    func didReceiveChainModelChanges(_: [DataProviderChange<ChainModel>]) {}

    func didReceiveBalance(results _: [ChainAssetId: Result<BigUInt?, Error>]) {}

    func didReceivePrices(result _: Result<[ChainAssetId: PriceData], Error>?) {}
}
