import Foundation
import RobinHood
import BigInt

protocol WalletListBaseInteractorInputProtocol: AnyObject {
    func setup()
}

protocol WalletListBaseInteractorOutputProtocol: AnyObject {
    func didReceiveChainModelChanges(_ changes: [DataProviderChange<ChainModel>])
    func didReceiveBalance(results: [ChainAssetId: Result<BigUInt?, Error>])
    func didReceivePrices(result: Result<[ChainAssetId: PriceData], Error>?)
}
