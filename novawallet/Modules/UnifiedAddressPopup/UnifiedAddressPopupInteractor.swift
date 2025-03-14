import UIKit

final class UnifiedAddressPopupInteractor {
    weak var presenter: UnifiedAddressPopupInteractorOutputProtocol?
}

extension UnifiedAddressPopupInteractor: UnifiedAddressPopupInteractorInputProtocol {}