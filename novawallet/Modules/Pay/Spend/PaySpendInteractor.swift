import UIKit

final class PaySpendInteractor {
    weak var presenter: PaySpendInteractorOutputProtocol?
}

extension PaySpendInteractor: PaySpendInteractorInputProtocol {}
