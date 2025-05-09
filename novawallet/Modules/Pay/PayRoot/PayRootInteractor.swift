import UIKit

final class PayRootInteractor {
    weak var presenter: PayRootInteractorOutputProtocol?
}

extension PayRootInteractor: PayRootInteractorInputProtocol {}
