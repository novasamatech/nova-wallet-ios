import UIKit

final class SelectRampProviderInteractor {
    weak var presenter: SelectRampProviderInteractorOutputProtocol?
}

extension SelectRampProviderInteractor: SelectRampProviderInteractorInputProtocol {}
