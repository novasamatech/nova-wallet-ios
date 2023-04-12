import UIKit

final class WalletConnectInteractor {
    weak var presenter: WalletConnectInteractorOutputProtocol?
}

extension WalletConnectInteractor: WalletConnectInteractorInputProtocol {}
