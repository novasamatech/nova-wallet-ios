import Foundation

protocol TransferConfirmOnChainInteractorProtocol: TransferConfirmOnChainInteractorInputProtocol {
    var submitionPresenter: TransferConfirmOnChainInteractorOutputProtocol? { get set }
}
