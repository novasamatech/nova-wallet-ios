import UIKit

final class PayShopInteractor {
    weak var presenter: PayShopInteractorOutputProtocol?
}

extension PayShopInteractor: PayShopInteractorInputProtocol {}
