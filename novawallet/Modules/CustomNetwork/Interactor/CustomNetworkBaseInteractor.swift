import UIKit

final class CustomNetworkBaseInteractor {
    weak var presenter: CustomNetworkInteractorOutputProtocol?
}

extension CustomNetworkBaseInteractor: CustomNetworkInteractorInputProtocol {}

enum ChainType {
    case substrate
    case evm
}
