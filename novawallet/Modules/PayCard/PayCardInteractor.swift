import UIKit

final class PayCardInteractor {
    weak var presenter: PayCardInteractorOutputProtocol?
}

extension PayCardInteractor: PayCardInteractorInputProtocol {}
