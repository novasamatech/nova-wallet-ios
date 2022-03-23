import UIKit

final class TransferConfirmInteractor {
    weak var presenter: TransferConfirmInteractorOutputProtocol!
}

extension TransferConfirmInteractor: TransferConfirmInteractorInputProtocol {}
