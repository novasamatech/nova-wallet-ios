import Foundation
import BigInt

final class TransferSetupPresenter {
    weak var view: TransferSetupViewProtocol?
    let wireframe: TransferSetupWireframeProtocol
    let interactor: TransferSetupInteractorInputProtocol

    init(
        interactor: TransferSetupInteractorInputProtocol,
        wireframe: TransferSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TransferSetupPresenter: TransferSetupPresenterProtocol {
    func setup() {}
}

extension TransferSetupPresenter: TransferSetupInteractorOutputProtocol {
    func didReceiveSendingAssetBalance(result: Result<AssetBalance?, Error>) {

    }

    func didReceiveUtilityAssetBalance(result: Result<AssetBalance?, Error>) {

    }

    func didReceiveFee(result: Result<BigUInt, Error>) {

    }

    func didReceiveSendingAssetPrice(result: Result<PriceData?, Error>) {

    }

    func didReceiveUtilityAssetPrice(result: Result<PriceData?, Error>) {

    }

    func didReceiveSetup(error: Error) {
        
    }
}
