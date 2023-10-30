import Foundation
import BigInt

final class SwapConfirmPresenter {
    weak var view: SwapConfirmViewProtocol?
    let wireframe: SwapConfirmWireframeProtocol
    let interactor: SwapConfirmInteractorInputProtocol

    init(
        interactor: SwapConfirmInteractorInputProtocol,
        wireframe: SwapConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SwapConfirmPresenter: SwapConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension SwapConfirmPresenter: SwapConfirmInteractorOutputProtocol {
    func didReceive(quote _: AssetConversion.Quote, for _: AssetConversion.QuoteArgs) {}

    func didReceive(fee _: AssetConversion.FeeModel?, transactionId _: TransactionFeeId) {}

    func didReceive(error _: SwapSetupError) {}

    func didReceive(price _: PriceData?, priceId _: AssetModel.PriceId) {}

    func didReceive(payAccountId _: AccountId?) {}

    func didReceive(balance _: AssetBalance?, for _: ChainAssetId, accountId _: AccountId) {}
}
