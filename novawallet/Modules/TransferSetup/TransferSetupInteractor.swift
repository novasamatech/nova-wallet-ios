import UIKit

final class TransferSetupInteractor {
    weak var presenter: TransferSetupInteractorOutputProtocol!
}

extension TransferSetupInteractor: TransferSetupInteractorInputProtocol {}
