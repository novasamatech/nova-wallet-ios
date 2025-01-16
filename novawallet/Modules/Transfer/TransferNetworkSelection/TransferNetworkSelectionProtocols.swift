import Foundation_iOS

protocol TransferNetworkSelectionViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [LocalizableResource<TransferNetworkSelectionViewModel>])
}

protocol TransferNetworkSelectionPresenterProtocol: AnyObject {
    func setup()
}

protocol TransferNetworkSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol TransferNetworkSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(balances: [ChainAssetId: AssetBalance], prices: [ChainAssetId: PriceData])
}
